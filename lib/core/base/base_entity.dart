import 'package:equatable/equatable.dart';

/// Base entity class for all domain entities
/// Entities represent core business objects
abstract class BaseEntity extends Equatable {
  const BaseEntity();

  /// Unique identifier for the entity
  String? get id;

  /// Convert entity to JSON
  /// Override this method in subclasses to provide JSON serialization

  @override
  List<Object?> get props => [id];
}
