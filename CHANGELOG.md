# Changelog

All notable changes to this project will be documented in this file.

## [1.0.0] - 2024-12-24

### Added
- Initial project setup with Clean Architecture
- Core layer with base classes, error handling, networking, and utilities
- Camera feature for capturing and uploading photos
  - Local camera data source
  - Remote photo upload
  - BLoC state management
  - Camera capture UI
- Destination feature for searching and selecting locations
  - Remote destination search
  - Destination selection
  - BLoC state management
  - Search UI with list view
- Navigation feature for real-time route display
  - Location tracking with Geolocator
  - Route calculation
  - Real-time location updates
  - Map view widget (placeholder)
  - BLoC state management
- Unified routing system with AppRouter
- Dependency injection with GetIt
- Material 3 theming (light and dark modes)
- Complete app flow: Camera → Destination → Navigation

### Dependencies
- flutter_bloc: ^8.1.6 - State management
- equatable: ^2.0.5 - Value equality
- get_it: ^8.0.3 - Dependency injection
- dio: ^5.7.0 - HTTP client
- shared_preferences: ^2.3.3 - Local storage
- dartz: ^0.10.1 - Functional programming
- camera: ^0.11.0+2 - Camera access
- geolocator: ^13.0.2 - Location services
- path_provider: ^2.1.5 - File system access
- logger: ^2.5.0 - Logging
- uuid: ^4.5.1 - UUID generation

### Architecture
- Clean Architecture with separation of concerns
- Domain, Data, and Presentation layers
- Repository pattern for data abstraction
- Use Case pattern for business logic
- BLoC pattern for state management
- Either monad for error handling

### Documentation
- Comprehensive README with architecture overview
- Setup instructions for Android and iOS
- Code examples and usage guidelines
