import 'package:flutter/foundation.dart';
import 'package:hiway_app/core/error/exceptions.dart';
import 'package:hiway_app/data/models/roadmap_resources_model.dart';
import 'package:hiway_app/data/services/roadmap_resources_service.dart';

class RoadmapResourcesProvider extends ChangeNotifier {
  final RoadmapResourcesService _service = RoadmapResourcesService();

  // Loading states
  bool _isLoading = false;
  bool _isSaving = false;

  // Error handling
  String? _errorMessage;

  // Data caching
  final Map<String, List<RoadmapResourcesModel>> _roadmapResourcesCache = {};
  final Map<String, RoadmapResourcesModel> _milestoneResourcesCache = {};
  List<RoadmapResourcesModel> _jobSeekerResources = [];

  // Getters
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  List<RoadmapResourcesModel> get jobSeekerResources => _jobSeekerResources;

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Get roadmap resources by roadmap ID (cached)
  List<RoadmapResourcesModel> getRoadmapResources(String roadmapId) {
    return _roadmapResourcesCache[roadmapId] ?? [];
  }

  /// Get milestone resources (cached)
  RoadmapResourcesModel? getMilestoneResources({
    required String roadmapId,
    required int milestoneIndex,
  }) {
    final key = '${roadmapId}_$milestoneIndex';
    return _milestoneResourcesCache[key];
  }

  /// Load roadmap resources for a specific roadmap
  Future<void> loadRoadmapResources(String roadmapId) async {
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final resources = await _service.getRoadmapResourcesByRoadmap(roadmapId);
      _roadmapResourcesCache[roadmapId] = resources;

      // Also update milestone cache
      for (final resource in resources) {
        final key = '${resource.roadmapId}_${resource.milestoneIndex}';
        _milestoneResourcesCache[key] = resource;
      }
    } catch (e) {
      _errorMessage = _getErrorMessage(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load specific milestone resources
  Future<RoadmapResourcesModel?> loadMilestoneResources({
    required String roadmapId,
    required int milestoneIndex,
  }) async {
    final key = '${roadmapId}_$milestoneIndex';

    // Return cached if available and not loading
    if (!_isLoading && _milestoneResourcesCache.containsKey(key)) {
      return _milestoneResourcesCache[key];
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final resource = await _service.getRoadmapResources(
        roadmapId: roadmapId,
        milestoneIndex: milestoneIndex,
      );

      if (resource != null) {
        _milestoneResourcesCache[key] = resource;
      }

      return resource;
    } catch (e) {
      _errorMessage = _getErrorMessage(e);
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load all job seeker resources
  Future<void> loadJobSeekerResources() async {
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _jobSeekerResources = await _service.getJobSeekerRoadmapResources();
    } catch (e) {
      _errorMessage = _getErrorMessage(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Save or update roadmap resources
  Future<RoadmapResourcesModel?> saveRoadmapResources({
    required String roadmapId,
    required int milestoneIndex,
    required List<dynamic> resources,
    required List<dynamic> certifications,
    required List<dynamic> networkGroups,
  }) async {
    if (_isSaving) return null;

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final savedResource = await _service.upsertRoadmapResources(
        roadmapId: roadmapId,
        milestoneIndex: milestoneIndex,
        resources: resources,
        certifications: certifications,
        networkGroups: networkGroups,
      );

      // Update caches
      final key = '${roadmapId}_$milestoneIndex';
      _milestoneResourcesCache[key] = savedResource;

      // Update roadmap cache
      final roadmapResources = _roadmapResourcesCache[roadmapId] ?? [];
      final existingIndex = roadmapResources.indexWhere(
        (r) => r.milestoneIndex == milestoneIndex,
      );

      if (existingIndex >= 0) {
        roadmapResources[existingIndex] = savedResource;
      } else {
        roadmapResources.add(savedResource);
        roadmapResources.sort(
          (a, b) => a.milestoneIndex.compareTo(b.milestoneIndex),
        );
      }
      _roadmapResourcesCache[roadmapId] = roadmapResources;

      // Update job seeker resources if loaded
      if (_jobSeekerResources.isNotEmpty) {
        final jobSeekerIndex = _jobSeekerResources.indexWhere(
          (r) => r.roadmapId == roadmapId && r.milestoneIndex == milestoneIndex,
        );

        if (jobSeekerIndex >= 0) {
          _jobSeekerResources[jobSeekerIndex] = savedResource;
        } else {
          _jobSeekerResources.insert(0, savedResource);
        }
      }

      return savedResource;
    } catch (e) {
      _errorMessage = _getErrorMessage(e);
      return null;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Delete roadmap resources
  Future<bool> deleteRoadmapResources({
    required String roadmapId,
    required int milestoneIndex,
  }) async {
    if (_isSaving) return false;

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _service.deleteRoadmapResources(
        roadmapId: roadmapId,
        milestoneIndex: milestoneIndex,
      );

      // Update caches
      final key = '${roadmapId}_$milestoneIndex';
      _milestoneResourcesCache.remove(key);

      // Update roadmap cache
      final roadmapResources = _roadmapResourcesCache[roadmapId] ?? [];
      roadmapResources.removeWhere((r) => r.milestoneIndex == milestoneIndex);
      _roadmapResourcesCache[roadmapId] = roadmapResources;

      // Update job seeker resources
      _jobSeekerResources.removeWhere(
        (r) => r.roadmapId == roadmapId && r.milestoneIndex == milestoneIndex,
      );

      return true;
    } catch (e) {
      _errorMessage = _getErrorMessage(e);
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Delete all resources for a roadmap
  Future<bool> deleteAllRoadmapResources(String roadmapId) async {
    if (_isSaving) return false;

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _service.deleteAllRoadmapResources(roadmapId);

      // Clear caches
      _roadmapResourcesCache.remove(roadmapId);

      // Clear milestone caches for this roadmap
      _milestoneResourcesCache.removeWhere(
        (key, value) => key.startsWith('${roadmapId}_'),
      );

      // Clear job seeker resources
      _jobSeekerResources.removeWhere((r) => r.roadmapId == roadmapId);

      return true;
    } catch (e) {
      _errorMessage = _getErrorMessage(e);
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Batch save multiple resources
  Future<List<RoadmapResourcesModel>?> batchSaveResources(
    List<Map<String, dynamic>> resourcesData,
  ) async {
    if (_isSaving) return null;

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final savedResources = await _service.batchUpsertResources(resourcesData);

      // Update all caches
      for (final resource in savedResources) {
        final key = '${resource.roadmapId}_${resource.milestoneIndex}';
        _milestoneResourcesCache[key] = resource;

        // Update roadmap cache
        final roadmapResources =
            _roadmapResourcesCache[resource.roadmapId] ?? [];
        final existingIndex = roadmapResources.indexWhere(
          (r) => r.milestoneIndex == resource.milestoneIndex,
        );

        if (existingIndex >= 0) {
          roadmapResources[existingIndex] = resource;
        } else {
          roadmapResources.add(resource);
        }
        _roadmapResourcesCache[resource.roadmapId] = roadmapResources;
      }

      // Refresh job seeker resources
      await loadJobSeekerResources();

      return savedResources;
    } catch (e) {
      _errorMessage = _getErrorMessage(e);
      return null;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Check if resources exist for milestone
  Future<bool> hasResourcesForMilestone({
    required String roadmapId,
    required int milestoneIndex,
  }) async {
    // Check cache first
    final key = '${roadmapId}_$milestoneIndex';
    if (_milestoneResourcesCache.containsKey(key)) {
      return true;
    }

    try {
      return await _service.hasResourcesForMilestone(
        roadmapId: roadmapId,
        milestoneIndex: milestoneIndex,
      );
    } catch (e) {
      return false;
    }
  }

  /// Get resources count for roadmap
  Future<int> getResourcesCount(String roadmapId) async {
    // Check cache first
    final cached = _roadmapResourcesCache[roadmapId];
    if (cached != null) {
      return cached.length;
    }

    try {
      return await _service.getResourcesCount(roadmapId);
    } catch (e) {
      return 0;
    }
  }

  /// Clear all caches
  void clearCache() {
    _roadmapResourcesCache.clear();
    _milestoneResourcesCache.clear();
    _jobSeekerResources.clear();
    notifyListeners();
  }

  /// Get error message from exception
  String _getErrorMessage(dynamic error) {
    if (error is AuthException) {
      return 'Authentication required. Please log in.';
    } else if (error is DatabaseException) {
      return error.message.isNotEmpty
          ? error.message
          : 'Database operation failed';
    } else if (error is NotFoundException) {
      return 'Roadmap resources not found';
    } else {
      return 'An unexpected error occurred: ${error.toString()}';
    }
  }

  @override
  void dispose() {
    clearCache();
    super.dispose();
  }
}
