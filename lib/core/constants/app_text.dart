/// Centralized app text for easy management and localization
class AppText {
  AppText._();

  // ============ App ============
  static const String appName = 'PathLogic';
  static const String appNameUppercase = 'PATHLOGIC';
  static const String appTagline = 'Indoor Navigation Assistant';
  static const String appTaglineUppercase = 'INDOOR NAVIGATION ASSISTANT';

  // ============ Onboarding ============
  static const String onboardingTitle1 = 'Welcome to PathLogic';
  static const String onboardingDesc1 =
      'You are all set! Let\'s quickly show you how to find your way around.';

  static const String onboardingTitle2 = 'Locate & Navigate';
  static const String onboardingDesc2 =
      'Search for any destination or use "Locate Me" to pinpoint your exact position on the map.';

  static const String onboardingTitle3 = 'Camera Tips';
  static const String onboardingDesc3 =
      'For best results, hold your camera steady and capture distinct features like corners or signage.';

  static const String onboardingSkip = 'Skip';
  static const String onboardingNext = 'Next';
  static const String onboardingGetStarted = 'Get Started';

  // ============ Dashboard ============
  static const String dashboardGreeting = 'Unav';
  static const String dashboardTagline = 'Indoor Navigation';
  static const String dashboardSearchHint = 'Search destination...';
  static const String dashboardPopularPlaces = 'Popular Places';
  static const String dashboardRecentDestinations = 'Recent Destinations';
  static const String dashboardSeeAll = 'See All';
  static const String dashboardLocateMe = 'Locate Me';
  static const String dashboardNavigateMe = 'Navigate Me';

  // ============ Locate Me ============
  static const String locateMeTitle = 'Locate Me';
  static const String locateMeCameraHint = 'Point camera at floor and walls';
  static const String locateMeSample = 'SAMPLE';
  static const String locateMeYourLocation = 'Your Location';
  static const String locateMeAnalyzing = 'Analyzing your location...';
  static const String locateMeLoadingFloorPlan = 'Loading floor plan...';
  static const String locateMeDeterminingPosition =
      'Determining your position...';
  static const String locateMeLoadingPlaces = 'Loading places of interest...';

  // ============ Camera ============
  static const String cameraTitle = 'Find me..';
  static const String cameraHint = 'Keep floor and walls in view';
  static const String cameraCeiling = 'CEILING';
  static const String cameraPath = 'PATH';
  static const String cameraFloor = 'FLOOR';
  static const String cameraIdealView = 'IDEAL VIEW';
  static const String cameraTapToClose = 'TAP ANYWHERE TO CLOSE';
  static const String cameraPhotoConfirmTitle = 'Is this photo clear?';
  static const String cameraPhotoConfirmDesc =
      'Ensure the image isn\'t blurry for best results.';
  static const String cameraConfirmAnalyze = 'Confirm & Analyze';
  static const String cameraRetake = 'Retake Photo';

  // ============ Navigation ============
  static const String navigationTitle = 'Route Preview';

  // ============ POI Bottom Sheet ============
  static const String poiFloor = 'Floor 6';
  static const String poiDistance = 'Distance';
  static const String poiEstTime = 'Est. Time';
  static const String poiNavigateHere = 'Navigate Me Here';
  static const String poiClose = 'Close';

  // ============ Common ============
  static const String commonError = 'Error';
  static const String commonRetry = 'Retry';
  static const String commonLoading = 'Loading...';
  static const String commonCancel = 'Cancel';
  static const String commonOk = 'OK';
  static const String commonSave = 'Save';
  static const String commonDelete = 'Delete';
  static const String commonEdit = 'Edit';
  static const String commonBack = 'Back';
  static const String commonNext = 'Next';
  static const String commonDone = 'Done';
  static const String commonContinue = 'Continue';

  // ============ Auth ============
  static const String authLogin = 'Login';
  static const String authSignup = 'Sign Up';
  static const String authLogout = 'Logout';
  static const String authEmail = 'Email';
  static const String authPassword = 'Password';
  static const String authForgotPassword = 'Forgot Password?';
  static const String authNoAccount = 'Don\'t have an account?';
  static const String authHaveAccount = 'Already have an account?';
}
