/// Расчётный движок приложения. Pure Dart.
///
/// Цели:
/// - Отделить бизнес‑правила (СП, ГОСТ, формулы) от UI на Flutter.
/// - Сделать ядро тестируемым юнит‑тестами без Flutter‑окружения.
/// - В будущем переиспользовать на серверном API.
///
/// Имеется один **жёсткий** принцип: каждая публичная функция возвращает
/// **результат расчёта со списком исходных данных и применённых норм**.
/// Это нужно для авто‑генерации пояснительной записки (ПЗ): ПЗ строится
/// прямо из этих структур, без повторного запуска расчёта.
library cc_engine;

export 'src/regions/snow_region.dart';
export 'src/regions/wind_region.dart';
export 'src/loads/snow_load.dart';
export 'src/loads/wind_load.dart';
export 'src/loads/permanent_load.dart';
export 'src/loads/foundation_loads.dart';
export 'src/foundation/soil_resistance.dart';
export 'src/foundation/strip_footing.dart';
export 'src/calc_step.dart';
