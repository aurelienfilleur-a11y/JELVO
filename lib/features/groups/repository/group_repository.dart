import 'package:flutter/material.dart';

import '../../../data/in_memory_collection.dart';
import '../models/group.dart';

abstract interface class GroupRepository {
  Stream<List<Group>> watchGroups();

  Group? findById(String id);

  void upsert(Group group);

  void remove(String id);
}

class InMemoryGroupRepository implements GroupRepository {
  InMemoryGroupRepository({Iterable<Group>? seed})
    : _collection = InMemoryCollection<Group>(
        idOf: (Group g) => g.id,
        seed: seed ?? demoGroups,
      );

  final InMemoryCollection<Group> _collection;

  @override
  Stream<List<Group>> watchGroups() => _collection.watch();

  @override
  Group? findById(String id) => _collection.findById(id);

  @override
  void upsert(Group group) => _collection.upsert(group);

  @override
  void remove(String id) => _collection.remove(id);

  static const List<Group> demoGroups = <Group>[
    Group(
      id: 'g1',
      name: 'Famille Rousseau',
      description: 'Anniversaires, vacances et rendez-vous médicaux',
      memberIds: <String>['c1', 'c3', 'c7'],
      accent: GroupAccent.violet,
      icon: Icons.home_rounded,
      upcomingEventCount: 3,
      openTaskCount: 2,
    ),
    Group(
      id: 'g2',
      name: 'Équipe produit',
      description: 'Sprints, points hebdo et rétrospectives',
      memberIds: <String>['c2', 'c5', 'c4'],
      accent: GroupAccent.indigo,
      icon: Icons.work_outline_rounded,
      upcomingEventCount: 5,
      openTaskCount: 4,
    ),
    Group(
      id: 'g3',
      name: 'Rando du dimanche',
      description: 'Sorties en montagne, covoiturage et ravitaillement',
      memberIds: <String>['c4', 'c6', 'c1', 'c2'],
      accent: GroupAccent.green,
      icon: Icons.terrain_rounded,
      upcomingEventCount: 1,
    ),
    Group(
      id: 'g4',
      name: 'Coloc Bastille',
      description: 'Ménage, courses et charges partagées',
      memberIds: <String>['c6', 'c4'],
      accent: GroupAccent.amber,
      icon: Icons.apartment_rounded,
      openTaskCount: 3,
    ),
  ];
}
