import 'dart:convert';
import 'package:dartz/dartz.dart';
import 'package:flutter/services.dart';
import '../../../../core/error/failures.dart';
import '../models/route_model.dart';
import '../../domain/entities/location_entity.dart';
import '../../domain/entities/route_entity.dart';
import '../../domain/repositories/navigation_repository.dart';
import '../datasources/navigation_local_datasource.dart';
import '../datasources/navigation_remote_datasource.dart';

class NavigationRepositoryImpl implements NavigationRepository {
  final NavigationLocalDataSource localDataSource;
  final NavigationRemoteDataSource remoteDataSource;

  NavigationRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
  });

  @override
  Future<Either<Failure, RouteEntity>> getRoute(
    LocationEntity? origin,
    LocationEntity destination,
  ) async {
    try {
      // Load dummy route from assets
      final String response = await rootBundle.loadString(
        'assets/mock_data/route.json',
      );
      final data = await json.decode(response);

      // Artificial delay to simulate network
      await Future.delayed(const Duration(milliseconds: 800));

      final routeModel = RouteModel.fromJson(data as Map<String, dynamic>);

      return Right(routeModel);
    } catch (e) {
      return Left(ServerFailure('Failed to load dummy route: $e'));
    }
  }
}
