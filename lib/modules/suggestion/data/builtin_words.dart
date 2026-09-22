/// 模块：suggestion / data
/// 职责：内置词库聚合器。
/// 约束：
///   1. 词条分散在 words/ 下按大类拆分的文件中。
///   2. 加词只改对应的分类文件，不动本文件。
library;

import '../domain/entities/candidate.dart';
import 'words/appliance.dart';
import 'words/automotive.dart';
import 'words/baby.dart';
import 'words/cleaning.dart';
import 'words/clothing.dart';
import 'words/daily.dart';
import 'words/digital.dart';
import 'words/furniture.dart';
import 'words/gardening.dart';
import 'words/hardware.dart';
import 'words/kitchen.dart';
import 'words/medicine.dart';
import 'words/other.dart';
import 'words/pet.dart';
import 'words/sports.dart';
import 'words/stationery.dart';
import 'words/tools.dart';

/// 大类 -> 词条列表。
const Map<String, List<String>> builtinWordsByGroup = {
  CandidateGroups.tools: wordsTools,
  CandidateGroups.digital: wordsDigital,
  CandidateGroups.kitchen: wordsKitchen,
  CandidateGroups.medicine: wordsMedicine,
  CandidateGroups.stationery: wordsStationery,
  CandidateGroups.daily: wordsDaily,
  CandidateGroups.cleaning: wordsCleaning,
  CandidateGroups.hardware: wordsHardware,
  CandidateGroups.clothing: wordsClothing,
  CandidateGroups.sports: wordsSports,
  CandidateGroups.baby: wordsBaby,
  CandidateGroups.pet: wordsPet,
  CandidateGroups.automotive: wordsAutomotive,
  CandidateGroups.furniture: wordsFurniture,
  CandidateGroups.appliance: wordsAppliance,
  CandidateGroups.gardening: wordsGardening,
  CandidateGroups.other: wordsOther,
};

/// 所有内置词的扁平列表。
const List<String> builtinWords = [
  ...wordsTools,
  ...wordsDigital,
  ...wordsKitchen,
  ...wordsMedicine,
  ...wordsStationery,
  ...wordsDaily,
  ...wordsCleaning,
  ...wordsHardware,
  ...wordsClothing,
  ...wordsSports,
  ...wordsBaby,
  ...wordsPet,
  ...wordsAutomotive,
  ...wordsFurniture,
  ...wordsAppliance,
  ...wordsGardening,
  ...wordsOther,
];