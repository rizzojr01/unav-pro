import 'package:equatable/equatable.dart';

/// Base entity class for domain layer
abstract class BaseEntity extends Equatable {
  const BaseEntity();

  @override
  List<Object?> get props => [];
}
