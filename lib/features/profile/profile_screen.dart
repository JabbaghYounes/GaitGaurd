import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'logic/profile_cubit.dart';
import '../../core/services/database_service.dart';
import '../../data/datasources/local/profile_local_data_source.dart';

/// Profile screen with view and edit capabilities.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late ProfileCubit _profileCubit;
  bool _isEditing = false;
  
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _bioController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  DateTime? _selectedDateOfBirth;

  @override
  void initState() {
    super.initState();
    _profileCubit = ProfileCubit(
      ProfileRepositoryImpl(DatabaseService.instance),
    );
    
    // For now, we'll use a hardcoded user ID. In a real app,
    // this would come from the authentication state.
    _profileCubit.loadProfile(1);
  }

  @override
  void dispose() {
    _profileCubit.close();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _displayNameController.dispose();
    _bioController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  void _populateFormFields(Profile profile) {
    _firstNameController.text = profile.firstName ?? '';
    _lastNameController.text = profile.lastName ?? '';
    _displayNameController.text = profile.displayName ?? '';
    _bioController.text = profile.bio ?? '';
    _phoneNumberController.text = profile.phoneNumber ?? '';
    _selectedDateOfBirth = profile.dateOfBirth;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    await _profileCubit.updateProfile(
      firstName: _firstNameController.text.trim().isEmpty 
          ? null 
          : _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim().isEmpty 
          ? null 
          : _lastNameController.text.trim(),
      displayName: _displayNameController.text.trim().isEmpty 
          ? null 
          : _displayNameController.text.trim(),
      bio: _bioController.text.trim().isEmpty 
          ? null 
          : _bioController.text.trim(),
      phoneNumber: _phoneNumberController.text.trim().isEmpty 
          ? null 
          : _phoneNumberController.text.trim(),
      dateOfBirth: _selectedDateOfBirth,
    );

    setState(() => _isEditing = false);
  }

  Future<void> _selectDateOfBirth(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateOfBirth ?? DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDateOfBirth) {
      setState(() {
        _selectedDateOfBirth = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => _profileCubit,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          actions: [
            BlocBuilder<ProfileCubit, ProfileState>(
              builder: (context, state) {
                if (state is! ProfileLoaded) return const SizedBox.shrink();
                
                return IconButton(
                  onPressed: () {
                    if (_isEditing) {
                      _saveProfile();
                    } else {
                      setState(() {
                        _isEditing = true;
                        _populateFormFields(state.profile);
                      });
                    }
                  },
                  icon: Icon(_isEditing ? Icons.check : Icons.edit),
                );
              },
            ),
          ],
        ),
        body: BlocConsumer<ProfileCubit, ProfileState>(
          listener: (context, state) {
            if (state is ProfileError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
              );
            }
          },
          builder: (context, state) {
            if (state is ProfileLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is ProfileError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      state.message,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _profileCubit.loadProfile(1),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            if (state is ProfileLoaded) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Header
                    Center(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 48,
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            child: Text(
                              state.profile.effectiveDisplayName
                                  .substring(0, 1)
                                  .toUpperCase(),
                              style: const TextStyle(
                                fontSize: 32,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (!_isEditing) ...[
                            Text(
                              state.profile.effectiveDisplayName,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            if (state.profile.email != null)
                              Text(
                                state.profile.email!,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Profile Form
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Personal Information',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 16),
                              
                              // Display Name
                              TextFormField(
                                controller: _displayNameController,
                                enabled: _isEditing,
                                decoration: const InputDecoration(
                                  labelText: 'Display Name',
                                  hintText: 'How others see you',
                                ),
                              ),
                              const SizedBox(height: 16),

                              // First Name and Last Name Row
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _firstNameController,
                                      enabled: _isEditing,
                                      decoration: const InputDecoration(
                                        labelText: 'First Name',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _lastNameController,
                                      enabled: _isEditing,
                                      decoration: const InputDecoration(
                                        labelText: 'Last Name',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Bio
                              TextFormField(
                                controller: _bioController,
                                enabled: _isEditing,
                                decoration: const InputDecoration(
                                  labelText: 'Bio',
                                  hintText: 'Tell us about yourself',
                                ),
                                maxLines: 3,
                              ),
                              const SizedBox(height: 16),

                              // Phone Number
                              TextFormField(
                                controller: _phoneNumberController,
                                enabled: _isEditing,
                                decoration: const InputDecoration(
                                  labelText: 'Phone Number',
                                  hintText: '+1 (555) 123-4567',
                                ),
                                keyboardType: TextInputType.phone,
                              ),
                              const SizedBox(height: 16),

                              // Date of Birth
                              InkWell(
                                onTap: _isEditing ? () => _selectDateOfBirth(context) : null,
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Date of Birth',
                                  ),
                                  child: Text(
                                    _selectedDateOfBirth != null
                                        ? '${_selectedDateOfBirth!.month}/${_selectedDateOfBirth!.day}/${_selectedDateOfBirth!.year}'
                                        : 'Select date',
                                    style: TextStyle(
                                      color: _selectedDateOfBirth != null
                                          ? null
                                          : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Settings Link
                    Card(
                      child: ListTile(
                        leading: Icon(
                          Icons.settings,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        title: const Text('Settings'),
                        subtitle: const Text('App preferences and privacy'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          // Show message for now - navigation handled by bottom nav
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Use the bottom navigation to access Settings'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}


