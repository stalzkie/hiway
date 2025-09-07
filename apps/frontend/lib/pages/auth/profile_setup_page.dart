import 'package:flutter/material.dart';
import 'package:hiway_app/core/constants/app_constants.dart';
import 'package:hiway_app/data/services/auth_service.dart';
import 'package:hiway_app/widgets/common/loading_widget.dart';
import 'package:hiway_app/widgets/profile/job_seeker_form.dart';
import 'package:hiway_app/widgets/profile/employer_form.dart';

class ProfileSetupPage extends StatefulWidget {
  final String email;

  const ProfileSetupPage({super.key, required this.email});

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();

  // Common controllers
  final _fullNameController = TextEditingController();

  // Job Seeker controllers
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _skillsController = TextEditingController();

  // Other data for job seeker
  final List<Map<String, dynamic>> _experienceList = [];
  final List<Map<String, dynamic>> _educationList = [];
  final List<Map<String, dynamic>> _licensesList = [];

  // Employer controllers
  final _companyController = TextEditingController();
  final _positionController = TextEditingController();
  final _companyEmailController = TextEditingController();
  final _companyPhoneController = TextEditingController();
  final _dtiOrSecController = TextEditingController();
  final _barangayClearanceController = TextEditingController();
  final _businessPermitController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  String _selectedRole = AppConstants.jobSeekerRole;

  @override
  void initState() {
    super.initState();
    _companyEmailController.text = widget.email;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _skillsController.dispose();
    _companyController.dispose();
    _positionController.dispose();
    _companyEmailController.dispose();
    _companyPhoneController.dispose();
    _dtiOrSecController.dispose();
    _barangayClearanceController.dispose();
    _businessPermitController.dispose();
    super.dispose();
  }

  Future<void> _createProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_selectedRole == AppConstants.jobSeekerRole) {
        await _authService.createJobSeekerProfileWithDetails(
          fullName: _fullNameController.text.trim(),
          email: widget.email,
          phone: _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
          address: _addressController.text.trim().isEmpty
              ? null
              : _addressController.text.trim(),
          skills: _skillsController.text.trim().isEmpty
              ? []
              : _skillsController.text
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList(),
          experience: _experienceList,
          education: _educationList,
          licensesCertifications: _licensesList,
        );
      } else {
        await _authService.createEmployerProfile(
          name: _fullNameController.text.trim(),
          company: _companyController.text.trim(),
          companyPosition: _positionController.text.trim(),
          companyEmail: _companyEmailController.text.trim(),
          companyPhoneNumber: _companyPhoneController.text.trim().isEmpty
              ? null
              : _companyPhoneController.text.trim(),
          dtiOrSecRegistration: _dtiOrSecController.text.trim().isEmpty
              ? null
              : _dtiOrSecController.text.trim(),
          barangayClearance: _barangayClearanceController.text.trim().isEmpty
              ? null
              : _barangayClearanceController.text.trim(),
          businessPermit: _businessPermitController.text.trim().isEmpty
              ? null
              : _businessPermitController.text.trim(),
        );
      }

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('DatabaseException: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.check_circle, color: Colors.green, size: 48),
        title: const Text('Account Created!'),
        content: const Text(
          'Your account has been created successfully! You can now sign in with your credentials.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushNamed(AppConstants.loginRoute);
            },
            child: const Text('Continue to Sign In'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
        centerTitle: true,
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),

                  Text(
                    'Tell us about yourself',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Choose your role and fill in your details',
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 32),

                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error,
                            color: Colors.red.shade600,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: Colors.red.shade600),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Role Selection
                  Text(
                    'I am a',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _isLoading
                              ? null
                              : () {
                                  setState(() {
                                    _selectedRole = AppConstants.jobSeekerRole;
                                  });
                                },
                          child: Row(
                            children: [
                              Radio<String>(
                                value: AppConstants.jobSeekerRole,
                                groupValue: _selectedRole,
                                onChanged: _isLoading
                                    ? null
                                    : (value) {
                                        setState(() {
                                          _selectedRole = value!;
                                        });
                                      },
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Job Seeker'),
                                    Text(
                                      'Looking for work',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: _isLoading
                              ? null
                              : () {
                                  setState(() {
                                    _selectedRole = AppConstants.employerRole;
                                  });
                                },
                          child: Row(
                            children: [
                              Radio<String>(
                                value: AppConstants.employerRole,
                                groupValue: _selectedRole,
                                onChanged: _isLoading
                                    ? null
                                    : (value) {
                                        setState(() {
                                          _selectedRole = value!;
                                        });
                                      },
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Employer'),
                                    Text(
                                      'Hiring talent',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  if (_selectedRole == AppConstants.jobSeekerRole)
                    _buildJobSeekerForm()
                  else
                    _buildEmployerForm(),

                  const SizedBox(height: 32),

                  LoadingButton(
                    onPressed: _createProfile,
                    isLoading: _isLoading,
                    child: const Text('Create My Profile'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildJobSeekerForm() {
    return JobSeekerForm(
      fullNameController: _fullNameController,
      phoneController: _phoneController,
      addressController: _addressController,
      skillsController: _skillsController,
      experienceList: _experienceList,
      educationList: _educationList,
      licensesList: _licensesList,
      onAddExperience: _handleAddExperience,
      onUpdateExperience: _handleUpdateExperience,
      onRemoveExperience: _removeExperience,
      onAddEducation: _handleAddEducation,
      onUpdateEducation: _handleUpdateEducation,
      onRemoveEducation: _removeEducation,
      onAddLicense: _handleAddLicense,
      onUpdateLicense: _handleUpdateLicense,
      onRemoveLicense: _removeLicense,
      isLoading: _isLoading,
    );
  }

  Widget _buildEmployerForm() {
    return EmployerForm(
      nameController: _fullNameController,
      companyController: _companyController,
      positionController: _positionController,
      companyEmailController: _companyEmailController,
      companyPhoneController: _companyPhoneController,
      dtiOrSecController: _dtiOrSecController,
      barangayClearanceController: _barangayClearanceController,
      businessPermitController: _businessPermitController,
      isLoading: _isLoading,
    );
  }

  // Profile Handler
  void _handleAddExperience(Map<String, dynamic> experience) {
    print('DEBUG: _handleAddExperience called with: $experience');
    setState(() {
      _experienceList.add(experience);
    });
    print('DEBUG: Experience list now has ${_experienceList.length} items');
  }

  void _handleUpdateExperience(int index, Map<String, dynamic> experience) {
    setState(() {
      _experienceList[index] = experience;
    });
  }

  void _removeExperience(int index) {
    setState(() {
      _experienceList.removeAt(index);
    });
  }

  void _handleAddEducation(Map<String, dynamic> education) {
    print('DEBUG: _handleAddEducation called with: $education');
    setState(() {
      _educationList.add(education);
    });
    print('DEBUG: Education list now has ${_educationList.length} items');
  }

  void _handleUpdateEducation(int index, Map<String, dynamic> education) {
    setState(() {
      _educationList[index] = education;
    });
  }

  void _removeEducation(int index) {
    setState(() {
      _educationList.removeAt(index);
    });
  }

  void _handleAddLicense(Map<String, dynamic> license) {
    print('DEBUG: _handleAddLicense called with: $license');
    setState(() {
      _licensesList.add(license);
    });
    print('DEBUG: License list now has ${_licensesList.length} items');
  }

  void _handleUpdateLicense(int index, Map<String, dynamic> license) {
    setState(() {
      _licensesList[index] = license;
    });
  }

  void _removeLicense(int index) {
    setState(() {
      _licensesList.removeAt(index);
    });
  }
}
