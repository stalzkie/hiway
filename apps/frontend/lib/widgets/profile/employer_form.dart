import 'package:flutter/material.dart';
import 'package:hiway_app/core/utils/validators.dart';

class EmployerForm extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController companyController;
  final TextEditingController positionController;
  final TextEditingController companyEmailController;
  final TextEditingController companyPhoneController;
  final TextEditingController dtiOrSecController;
  final TextEditingController barangayClearanceController;
  final TextEditingController businessPermitController;
  final bool isLoading;

  const EmployerForm({
    super.key,
    required this.nameController,
    required this.companyController,
    required this.positionController,
    required this.companyEmailController,
    required this.companyPhoneController,
    required this.dtiOrSecController,
    required this.barangayClearanceController,
    required this.businessPermitController,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Company Information',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),

        // Contact Person Name
        TextFormField(
          controller: nameController,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Contact Person Name *',
            prefixIcon: Icon(Icons.person),
          ),
          validator: Validators.validateFullName,
          enabled: !isLoading,
        ),

        const SizedBox(height: 16),

        // Company Name
        TextFormField(
          controller: companyController,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Company Name *',
            prefixIcon: Icon(Icons.business),
          ),
          validator: Validators.validateCompanyName,
          enabled: !isLoading,
        ),

        const SizedBox(height: 16),

        // Position
        TextFormField(
          controller: positionController,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Your Position *',
            prefixIcon: Icon(Icons.work),
          ),
          validator: Validators.validatePosition,
          enabled: !isLoading,
        ),

        const SizedBox(height: 16),

        // Company Email
        TextFormField(
          controller: companyEmailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Company Email *',
            prefixIcon: Icon(Icons.email),
          ),
          validator: Validators.validateEmail,
          enabled: !isLoading,
        ),

        const SizedBox(height: 16),

        // Company Phone
        TextFormField(
          controller: companyPhoneController,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Company Phone Number',
            prefixIcon: Icon(Icons.phone),
            helperText: 'Format: +639123456789 or 09123456789',
          ),
          validator: Validators.validatePhoneNumber,
          enabled: !isLoading,
        ),

        const SizedBox(height: 24),

        Text(
          'Business Documents (Optional)',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),

        Text(
          'These documents help verify your business and build trust with job seekers.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 16),

        // DTI or SEC Registration
        TextFormField(
          controller: dtiOrSecController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'DTI or SEC Registration Number',
            prefixIcon: Icon(Icons.document_scanner),
            helperText: 'Your business registration number',
          ),
          validator: (value) =>
              Validators.validateOptionalText(value, 'DTI/SEC Registration'),
          enabled: !isLoading,
        ),

        const SizedBox(height: 16),

        // Barangay Clearance
        TextFormField(
          controller: barangayClearanceController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Barangay Clearance',
            prefixIcon: Icon(Icons.verified_user),
            helperText: 'Your barangay clearance number',
          ),
          validator: (value) =>
              Validators.validateOptionalText(value, 'Barangay Clearance'),
          enabled: !isLoading,
        ),

        const SizedBox(height: 16),

        // Business Permit
        TextFormField(
          controller: businessPermitController,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Business Permit',
            prefixIcon: Icon(Icons.business_center),
            helperText: 'Your business permit number',
          ),
          validator: (value) =>
              Validators.validateOptionalText(value, 'Business Permit'),
          enabled: !isLoading,
        ),
      ],
    );
  }
}
