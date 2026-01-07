import 'package:dartz/dartz.dart';
import 'package:smart_sense/core/error/failures.dart';
import '../entities/user_entity.dart';

abstract class ProfileRepository {
  Future<Either<Failure, UserEntity>> getMe();
}
