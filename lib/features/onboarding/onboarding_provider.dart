import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/user_repository.dart';

const kOccupations = [
  'Student',
  'Teacher / Educator',
  'Engineer',
  'Doctor / Healthcare',
  'Lawyer',
  'Accountant / Finance',
  'Business Owner',
  'Artist / Designer',
  'Writer / Journalist',
  'Software Developer',
  'Homemaker',
  'Retired',
  'Other',
];

const kGenders = [
  'Male',
  'Female',
  'Non-binary',
  'Prefer not to say',
];

class OnboardingState {
  final String name;
  final DateTime? dateOfBirth;
  final String occupation; // selected from list OR 'Other'
  final String customOccupation; // typed value when occupation == 'Other'
  final DateTime? marriedOn;
  final String gender;
  final String relationshipStatus; // 'single', 'committed', 'engaged', 'married'
  final String relationshipDistance;
  final bool isLoading;
  final String? error;

  const OnboardingState({
    this.name = '',
    this.dateOfBirth,
    this.occupation = '',
    this.customOccupation = '',
    this.marriedOn,
    this.gender = '',
    this.relationshipStatus = '',
    this.relationshipDistance = 'moderate',
    this.isLoading = false,
    this.error,
  });

  OnboardingState copyWith({
    String? name,
    DateTime? dateOfBirth,
    String? occupation,
    String? customOccupation,
    DateTime? marriedOn,
    bool? clearMarriedOn,
    String? gender,
    String? relationshipStatus,
    String? relationshipDistance,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return OnboardingState(
      name: name ?? this.name,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      occupation: occupation ?? this.occupation,
      customOccupation: customOccupation ?? this.customOccupation,
      marriedOn:
          (clearMarriedOn == true) ? null : (marriedOn ?? this.marriedOn),
      gender: gender ?? this.gender,
      relationshipStatus: relationshipStatus ?? this.relationshipStatus,
      relationshipDistance: relationshipDistance ?? this.relationshipDistance,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  String get effectiveOccupation =>
      occupation == 'Other' ? customOccupation : occupation;

  bool get isPersonalInfoValid {
    return name.trim().isNotEmpty &&
        dateOfBirth != null &&
        gender.isNotEmpty &&
        effectiveOccupation.trim().isNotEmpty;
  }
}

class OnboardingNotifier extends StateNotifier<OnboardingState> {
  final UserRepository _userRepo;
  
  OnboardingNotifier(this._userRepo) : super(const OnboardingState());

  void setName(String v) => state = state.copyWith(name: v, clearError: true);
  void setDOB(DateTime v) =>
      state = state.copyWith(dateOfBirth: v, clearError: true);
  void setOccupation(String v) =>
      state = state.copyWith(occupation: v, clearError: true);
  void setCustomOccupation(String v) =>
      state = state.copyWith(customOccupation: v, clearError: true);
  void setMarriedOn(DateTime v) =>
      state = state.copyWith(marriedOn: v, clearError: true);
  void setGender(String v) => state = state.copyWith(gender: v, clearError: true);
  void setRelationshipStatus(String v) =>
      state = state.copyWith(relationshipStatus: v, clearError: true);
  void setRelationshipDistance(String v) =>
      state = state.copyWith(relationshipDistance: v);

  Future<void> submitProfile() async {
    state = state.copyWith(isLoading: true, clearError: true);
    
    try {
      final isReg = await _userRepo.isUserRegistered();
      if (!isReg) {
        await _userRepo.createUserProfile(
          name: state.name,
          dateOfBirth: state.dateOfBirth!,
          occupation: state.effectiveOccupation,
          gender: state.gender,
          relationshipStatus: state.relationshipStatus,
          marriedOn: state.marriedOn,
          relationshipDistance: state.relationshipDistance,
        );
      }
      
      // We do NOT set hasProfile here anymore. 
      // We wait until the final onboarding step is complete.
      
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }
}

final onboardingProvider = StateNotifierProvider<OnboardingNotifier, OnboardingState>(
  (ref) {
    final userRepo = ref.watch(userRepositoryProvider);
    return OnboardingNotifier(userRepo);
  },
);
