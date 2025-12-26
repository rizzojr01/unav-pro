# Smart Sense - UI Design Documentation

## Color Palette

### Primary Colors
- **Primary**: `#6C5CE7` (Purple) - Main brand color
- **Primary Dark**: `#5443C3` - Hover/pressed states
- **Primary Light**: `#8B7FF5` - Highlights & gradients

### Secondary Colors
- **Secondary**: `#00B894` (Green) - Success & secondary actions
- **Secondary Dark**: `#009977`
- **Secondary Light**: `#26D9A8`

### Accent Colors
- **Accent**: `#FF7675` (Red) - Error & important actions
- **Accent Dark**: `#E85654`
- **Accent Light**: `#FF9F9E`

### Status Colors
- **Success**: `#00B894` - Success messages & states
- **Error**: `#FF7675` - Error messages & states
- **Warning**: `#FDCB6E` - Warning messages & states
- **Info**: `#74B9FF` - Info messages & states

## Custom Widgets

### 1. CustomButton
A versatile button widget with:
- Regular and outlined variants
- Loading state
- Icon support
- Custom colors
- Full-width option

```dart
CustomButton(
  text: 'Login',
  onPressed: () {},
  icon: Icons.login,
  isLoading: false,
  isOutlined: false,
  width: double.infinity,
)
```

### 2. CustomTextField
Professional text input field with:
- Prefix and suffix icons
- Password visibility toggle
- Validation support
- Themed styling

```dart
CustomTextField(
  controller: _controller,
  labelText: 'Email',
  hintText: 'Enter your email',
  prefixIcon: Icons.email_outlined,
  validator: (value) => value?.isEmpty == true ? 'Required' : null,
)
```

### 3. CustomCard
Elegant card widget with:
- Shadow option
- Custom padding/margin
- Tap handling
- Rounded corners

```dart
CustomCard(
  hasShadow: true,
  onTap: () {},
  child: YourContent(),
)
```

### 4. CustomSnackBar
Beautiful snackbar notifications with:
- Success, Error, Warning, Info types
- Auto-dismiss
- Icon support
- Floating style

```dart
CustomSnackBar.show(
  context,
  message: 'Login successful!',
  type: SnackBarType.success,
)
```

### 5. LoadingOverlay
Full-screen loading overlay with:
- Semi-transparent background
- Loading indicator
- Optional message

```dart
LoadingOverlay(
  isLoading: true,
  message: 'Please wait...',
  child: YourContent(),
)
```

## Screen Flow

1. **Splash Screen** → Animated intro with app logo
2. **Onboarding** → 3-page introduction to app features
3. **Login** → Authentication with guest option
4. **Camera** → Photo capture interface
5. **Destination** → Search and select destination
6. **Navigation** → Live navigation with route info

## Design Principles

### Visual Hierarchy
- Large, bold headers for section titles
- Clear typography with proper font weights
- Consistent spacing using 8px grid system

### Colors & Gradients
- Gradient backgrounds for important screens (Splash, Onboarding)
- Status colors for feedback (green=success, red=error, yellow=warning)
- Neutral grays for secondary content

### Animations
- Fade & scale animations on splash screen
- Page transitions with smooth curves
- Loading states with circular progress indicators

### Accessibility
- High contrast text colors
- Large touch targets (minimum 48px)
- Clear focus states
- Readable font sizes (14-20px)

## Widget Composition

All UI screens are composed of reusable custom widgets instead of inline builders:

**❌ Avoid:**
```dart
Widget _buildButton() {
  return ElevatedButton(...);
}
```

**✅ Prefer:**
```dart
CustomButton(text: 'Click me', onPressed: () {})
```

## File Structure

```
lib/
├── theme/
│   ├── app_colors.dart       # Color constants
│   └── app_theme.dart        # Theme configuration
├── shared/
│   └── widgets/
│       ├── custom_button.dart
│       ├── custom_card.dart
│       ├── custom_snackbar.dart
│       ├── custom_text_field.dart
│       ├── loading_overlay.dart
│       └── widgets.dart      # Export file
├── features/
│   ├── splash/
│   ├── onboarding/
│   ├── auth/
│   ├── camera/
│   ├── destination/
│   └── navigation/
└── routes/
    └── app_router.dart
```

## Best Practices

1. **Always use AppColors** - Never hardcode colors
2. **Use custom widgets** - Maintain consistency across the app
3. **Keep widgets small** - Extract complex UI into separate widget classes
4. **Meaningful names** - Use descriptive class names (e.g., `_CameraReadyView`)
5. **Const constructors** - Use `const` wherever possible for performance
6. **Responsive design** - Use flexible widgets like `Expanded`, `Flexible`

## Maintenance

When updating the UI:
1. Update color constants in `app_colors.dart`
2. Modify custom widgets in `shared/widgets/`
3. Test across all screens
4. Update this documentation
5. Format code with `dart format`
6. Check for errors with `flutter analyze`
