import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/drawing.dart';
import '../models/floor_plan.dart';
import '../models/house_project.dart';
import '../widgets/floor_plan_view.dart' show FloorPlanView;

/// Сборка комплекта планов в PDF (формат A3, ландшафт). На каждый
/// лист — один [FloorPlan] (схематический план этажа). В заголовке —
/// название проекта, номер версии, дата. Внизу штамп с реквизитами.
class PdfBuilder {
  PdfBuilder._();

  static Future<Uint8List> buildBatch({
    required HouseProject project,
    required List<Drawing> drawings,
    required int versionNumber,
  }) async {
    // Берём только листы со схематическими планами; именно они содержат
    // FloorPlan в payload и имеют смысл на чертеже.
    final plans = <(Drawing, FloorPlan)>[];
    for (final d in drawings) {
      if (d.kind != DrawingKind.schematicPlan) continue;
      final plan = FloorPlan.tryDecode(d.payload);
      if (plan != null) plans.add((d, plan));
    }

    // Загружаем кириллический шрифт из ассетов. Встроенный Helvetica
    // умеет только Latin-1 и падает с ArgumentError на «Лестница» / «Спальня».
    final regularData = await rootBundle.load('assets/fonts/DejaVuSans.ttf');
    final boldData = await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf');
    final regular = pw.Font.ttf(regularData);
    final bold = pw.Font.ttf(boldData);

    final pdf = pw.Document(
      title: '${project.name} — Версия №$versionNumber',
      author: 'Construction Calculator',
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );

    // Регистрируем PdfTtfFont в документе и используем напрямую в
    // PdfGraphics painter — иначе canvas.defaultFont вернёт Helvetica
    // (он добавляется первым) и кириллица упадёт.
    final pdfTtfRegular = PdfTtfFont(pdf.document, regularData);

    if (plans.isEmpty) {
      pdf.addPage(_emptyPage(regular));
    } else {
      for (final pair in plans) {
        pdf.addPage(_planPage(
          project: project,
          drawing: pair.$1,
          plan: pair.$2,
          versionNumber: versionNumber,
          font: regular,
          fontBold: bold,
          pdfFont: pdfTtfRegular,
        ));
      }
    }

    return pdf.save();
  }

  static pw.Page _emptyPage(pw.Font font) {
    return pw.Page(
      pageFormat: PdfPageFormat.a3.landscape,
      build: (context) => pw.Center(
        child: pw.Text(
          'Нет схематических планов в этой версии.',
          style: pw.TextStyle(fontSize: 14, font: font),
        ),
      ),
    );
  }

  static pw.Page _planPage({
    required HouseProject project,
    required Drawing drawing,
    required FloorPlan plan,
    required int versionNumber,
    required pw.Font font,
    required pw.Font fontBold,
    required PdfFont pdfFont,
  }) {
    return pw.Page(
      pageFormat: PdfPageFormat.a3.landscape,
      margin: const pw.EdgeInsets.all(20),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _header(project, drawing, plan, versionNumber, font, fontBold),
            pw.SizedBox(height: 8),
            pw.Expanded(
              child: pw.LayoutBuilder(
                builder: (context, constraints) {
                  return pw.SizedBox(
                    width: constraints!.maxWidth,
                    height: constraints.maxHeight,
                    child: pw.CustomPaint(
                      size: PdfPoint(
                        constraints.maxWidth,
                        constraints.maxHeight,
                      ),
                      painter: (canvas, size) =>
                          _paintPlan(canvas, size, plan, pdfFont),
                    ),
                  );
                },
              ),
            ),
            _footer(plan, font),
          ],
        );
      },
    );
  }

  static pw.Widget _header(
    HouseProject project,
    Drawing drawing,
    FloorPlan plan,
    int versionNumber,
    pw.Font font,
    pw.Font fontBold,
  ) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              project.name,
              style: pw.TextStyle(
                fontSize: 14,
                font: fontBold,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(
              '${plan.floorLabel} · ${drawing.title}',
              style: pw.TextStyle(fontSize: 11, font: font),
            ),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('Версия №$versionNumber',
                style: pw.TextStyle(fontSize: 11, font: font)),
            pw.Text(
              _formatDate(drawing.createdAt),
              style: pw.TextStyle(fontSize: 9, font: font),
            ),
            if (drawing.isManualEdit)
              pw.Text('ручная правка',
                  style: pw.TextStyle(
                    fontSize: 9,
                    font: font,
                    color: PdfColors.deepOrange,
                    fontStyle: pw.FontStyle.italic,
                  )),
          ],
        ),
      ],
    );
  }

  static pw.Widget _footer(FloorPlan plan, pw.Font font) {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(width: 0.5)),
      ),
      padding: const pw.EdgeInsets.only(top: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Габариты этажа: ${plan.width.toStringAsFixed(2)} × '
            '${plan.height.toStringAsFixed(2)} м',
            style: pw.TextStyle(fontSize: 9, font: font),
          ),
          pw.Text(
            'Construction Calculator',
            style: pw.TextStyle(
              fontSize: 9,
              font: font,
              color: PdfColors.grey600,
            ),
          ),
        ],
      ),
    );
  }

  // Толщина стен (м), синхронно с FloorPlanView.
  static const double _outerWall = FloorPlanView.outerWall;
  static const double _innerWall = FloorPlanView.innerWall;
  static const double _eps = 0.05;

  // Палитра PDF.
  static const PdfColor _wallMassColor = PdfColors.grey800;
  static const PdfColor _surfaceColor = PdfColors.white;
  static const PdfColor _roomFill = PdfColors.blue100;
  static const PdfColor _staircaseFill = PdfColors.deepPurple100;
  static const PdfColor _staircaseStroke = PdfColors.deepPurple400;
  static const PdfColor _freeFill = PdfColors.amber100;
  static const PdfColor _doorColor = PdfColors.teal700;
  static const PdfColor _entryDoorColor = PdfColors.red700;
  static const PdfColor _windowFill = PdfColors.lightBlue50;
  static const PdfColor _windowStroke = PdfColors.blue700;

  /// Рисует план так же, как `FloorPlanPainter` на экране:
  ///   1) пятно заливается «массой стены» (тёмный onSurface);
  ///   2) поверх — внутренние прямоугольники комнат, отступ от рёбер равен
  ///      половине толщины стены (наружная 0.38 м, внутренняя 0.20 м) —
  ///      это даёт визуальный эффект толстых стен;
  ///   3) проёмы «вырезают» стену: окно — двойная линия (CAD-символ),
  ///      дверь — створка + дуга направления открывания, открытый проход —
  ///      просто заливка цветом свободной зоны;
  ///   4) лестница — штриховка ступеней + стрелка подъёма.
  static void _paintPlan(
    PdfGraphics canvas,
    PdfPoint size,
    FloorPlan plan,
    PdfFont font,
  ) {
    final w = size.x;
    final h = size.y;
    const padding = 24.0;
    final scaleX = (w - 2 * padding) / plan.width;
    final scaleY = (h - 2 * padding) / plan.height;
    final scale = scaleX < scaleY ? scaleX : scaleY;
    final planW = plan.width * scale;
    final planH = plan.height * scale;
    final ox = (w - planW) / 2;
    final oy = (h - planH) / 2;

    // PdfGraphics ось Y направлена вверх. У нас в модели — вниз.
    PdfPoint pp(double mx, double my) =>
        PdfPoint(ox + mx * scale, oy + planH - my * scale);

    void fillRectM(double mx, double my, double mw, double mh) {
      final tl = pp(mx, my);
      canvas.drawRect(tl.x, tl.y - mh * scale, mw * scale, mh * scale);
      canvas.fillPath();
    }

    void strokeRectM(
      double mx,
      double my,
      double mw,
      double mh,
    ) {
      final tl = pp(mx, my);
      canvas.drawRect(tl.x, tl.y - mh * scale, mw * scale, mh * scale);
      canvas.strokePath();
    }

    // 1. Заливка всего пятна цветом массы стены.
    canvas.setFillColor(_wallMassColor);
    fillRectM(0, 0, plan.width, plan.height);

    // 2. Внутренние прямоугольники комнат поверх стен.
    for (final r in plan.rooms) {
      final inner = _innerRect(r, plan);
      if (inner == null) continue;
      final fillColor = switch (r.kind) {
        PlanRoomKind.staircase => _staircaseFill,
        PlanRoomKind.free => _freeFill,
        PlanRoomKind.room => _roomFill,
      };
      canvas.setFillColor(fillColor);
      fillRectM(inner.mx, inner.my, inner.mw, inner.mh);
      if (r.kind == PlanRoomKind.staircase) {
        _drawStaircasePattern(canvas, pp, inner);
      }
    }

    // 3. Проёмы — окна, двери, открытые проходы.
    for (final o in plan.openings) {
      _drawOpening(canvas, plan, o, pp, scale);
    }

    // 4. Подписи комнат.
    for (final r in plan.rooms) {
      final inner = _innerRect(r, plan);
      if (inner == null) continue;
      final innerWPx = inner.mw * scale;
      final innerHPx = inner.mh * scale;
      if (innerWPx < 30 || innerHPx < 24) continue;
      final cx = ox + (inner.mx + inner.mw / 2) * scale;
      final cy = oy + planH - (inner.my + inner.mh / 2) * scale;
      _drawCenteredText(
        canvas,
        '${r.label}\n${r.area.toStringAsFixed(1)} м²',
        cx,
        cy,
        fontSize: innerWPx > 80 ? 9 : 7,
        font: font,
      );
    }

    // 5. Внешний контур пятна — поверх всего.
    canvas.setStrokeColor(PdfColors.black);
    canvas.setLineWidth(1.0);
    strokeRectM(0, 0, plan.width, plan.height);
  }

  /// Внутренний прямоугольник комнаты с учётом толщины стен.
  /// Возвращает `null`, если стены «съели» всю комнату.
  static _RectM? _innerRect(PlanRoom r, FloorPlan plan) {
    final left = _isOuter(r.x, 0) ? _outerWall / 2 : _innerWall / 2;
    final right = _isOuter(r.x + r.width, plan.width)
        ? _outerWall / 2
        : _innerWall / 2;
    final top = _isOuter(r.y, 0) ? _outerWall / 2 : _innerWall / 2;
    final bottom = _isOuter(r.y + r.height, plan.height)
        ? _outerWall / 2
        : _innerWall / 2;
    final innerW = r.width - left - right;
    final innerH = r.height - top - bottom;
    if (innerW <= 0 || innerH <= 0) return null;
    return _RectM(r.x + left, r.y + top, innerW, innerH);
  }

  static bool _isOuter(double v, double boundary) =>
      (v - boundary).abs() < _eps;

  static bool _isOpeningOnOuterWall(FloorPlan plan, PlanOpening o) {
    switch (o.side) {
      case WallSide.top:
        return o.y < _eps;
      case WallSide.bottom:
        return (plan.height - o.y).abs() < _eps;
      case WallSide.left:
        return o.x < _eps;
      case WallSide.right:
        return (plan.width - o.x).abs() < _eps;
    }
  }

  static void _drawOpening(
    PdfGraphics canvas,
    FloorPlan plan,
    PlanOpening o,
    PdfPoint Function(double, double) pp,
    double scale,
  ) {
    final isExternal = _isOpeningOnOuterWall(plan, o);
    final thickness = isExternal ? _outerWall : _innerWall;
    final isVerticalWall = !o.side.isHorizontal;

    // Прямоугольник проёма в модельных координатах (Y вниз).
    final double mx, my, mw, mh;
    if (isVerticalWall) {
      mx = o.x - thickness / 2;
      my = o.y;
      mw = thickness;
      mh = o.length;
    } else {
      mx = o.x;
      my = o.y - thickness / 2;
      mw = o.length;
      mh = thickness;
    }

    void fillRect(PdfColor c) {
      canvas.setFillColor(c);
      final tl = pp(mx, my);
      canvas.drawRect(tl.x, tl.y - mh * scale, mw * scale, mh * scale);
      canvas.fillPath();
    }

    if (o.kind == OpeningKind.archway) {
      // Открытый проход — две свободные зоны соединены, рисуем заливку.
      fillRect(_freeFill);
      return;
    }

    if (o.kind == OpeningKind.window) {
      // Окно — заливка + контур + двойная линия (стандартный CAD-символ).
      fillRect(_windowFill);
      canvas.setStrokeColor(_windowStroke);
      canvas.setLineWidth(0.7);
      final tl = pp(mx, my);
      canvas.drawRect(tl.x, tl.y - mh * scale, mw * scale, mh * scale);
      canvas.strokePath();
      // Две параллельные линии вдоль стены.
      const double inset = 0.04;
      if (isVerticalWall) {
        final m1 = mx + mw * 0.33;
        final m2 = mx + mw * 0.67;
        final p1a = pp(m1, my + inset);
        final p1b = pp(m1, my + mh - inset);
        final p2a = pp(m2, my + inset);
        final p2b = pp(m2, my + mh - inset);
        canvas.drawLine(p1a.x, p1a.y, p1b.x, p1b.y);
        canvas.strokePath();
        canvas.drawLine(p2a.x, p2a.y, p2b.x, p2b.y);
        canvas.strokePath();
      } else {
        final m1 = my + mh * 0.33;
        final m2 = my + mh * 0.67;
        final p1a = pp(mx + inset, m1);
        final p1b = pp(mx + mw - inset, m1);
        final p2a = pp(mx + inset, m2);
        final p2b = pp(mx + mw - inset, m2);
        canvas.drawLine(p1a.x, p1a.y, p1b.x, p1b.y);
        canvas.strokePath();
        canvas.drawLine(p2a.x, p2a.y, p2b.x, p2b.y);
        canvas.strokePath();
      }
      return;
    }

    // Дверь: «вырезаем» стену цветом пола, рисуем створку и дугу.
    fillRect(_surfaceColor);
    final isEntry = o.kind == OpeningKind.externalDoor;
    final color = isEntry ? _entryDoorColor : _doorColor;
    canvas.setStrokeColor(color);
    canvas.setLineWidth(isEntry ? 1.4 : 1.0);

    // Координаты hinge / leaf-end в модельной системе (Y вниз).
    final double hingeX, hingeY, leafX, leafY;
    final double startAngle;
    const double sweep = math.pi / 2;
    if (isVerticalWall) {
      final centerM = mx + mw / 2;
      if (o.swing >= 0) {
        hingeX = centerM;
        hingeY = my;
        leafX = centerM + o.length;
        leafY = my;
        startAngle = 0;
      } else {
        hingeX = centerM;
        hingeY = my + mh;
        leafX = centerM + o.length;
        leafY = my + mh;
        startAngle = -math.pi / 2;
      }
    } else {
      final centerM = my + mh / 2;
      if (o.swing >= 0) {
        hingeX = mx;
        hingeY = centerM;
        leafX = mx;
        leafY = centerM + o.length;
      } else {
        hingeX = mx + mw;
        hingeY = centerM;
        leafX = mx + mw;
        leafY = centerM + o.length;
      }
      startAngle = math.pi / 2;
    }

    // Створка (полотно).
    final hp = pp(hingeX, hingeY);
    final lp = pp(leafX, leafY);
    canvas.drawLine(hp.x, hp.y, lp.x, lp.y);
    canvas.strokePath();

    // Дуга направления открывания — четверть круга от leafEnd к перпендикуляру.
    canvas.setStrokeColor(_lighten(color, 0.45));
    canvas.setLineWidth(0.6);
    _drawArcM(
      canvas,
      pp,
      cxM: hingeX,
      cyM: hingeY,
      radiusM: o.length,
      startAngle: startAngle,
      sweep: sweep,
    );

    if (isEntry) {
      // Жирная отметка стороны улицы — короткий штрих наружу.
      canvas.setStrokeColor(color);
      canvas.setLineWidth(1.6);
      final outX = isVerticalWall
          ? (o.side == WallSide.left ? mx - 0.25 : mx + mw + 0.25)
          : mx + mw / 2;
      final outY = isVerticalWall
          ? my + mh / 2
          : (o.side == WallSide.top ? my - 0.25 : my + mh + 0.25);
      final innX = isVerticalWall
          ? (o.side == WallSide.left ? mx + mw : mx)
          : mx + mw / 2;
      final innY = isVerticalWall ? my + mh / 2 : my + mh / 2;
      final a = pp(outX, outY);
      final b = pp(innX, innY);
      canvas.drawLine(a.x, a.y, b.x, b.y);
      canvas.strokePath();
    }
  }

  /// Полилиния-аппроксимация дуги в модельных координатах. [steps]
  /// сегментов хватает на гладкую кривую при печати A3.
  static void _drawArcM(
    PdfGraphics canvas,
    PdfPoint Function(double, double) pp, {
    required double cxM,
    required double cyM,
    required double radiusM,
    required double startAngle,
    required double sweep,
    int steps = 24,
  }) {
    final p0 = pp(
      cxM + radiusM * math.cos(startAngle),
      cyM + radiusM * math.sin(startAngle),
    );
    canvas.moveTo(p0.x, p0.y);
    for (var i = 1; i <= steps; i++) {
      final a = startAngle + sweep * i / steps;
      final p = pp(
        cxM + radiusM * math.cos(a),
        cyM + radiusM * math.sin(a),
      );
      canvas.lineTo(p.x, p.y);
    }
    canvas.strokePath();
  }

  static void _drawStaircasePattern(
    PdfGraphics canvas,
    PdfPoint Function(double, double) pp,
    _RectM r,
  ) {
    canvas.setStrokeColor(_staircaseStroke);
    canvas.setLineWidth(0.6);
    final horizontal = r.mw >= r.mh;
    const steps = 8;
    if (horizontal) {
      final stepW = r.mw / steps;
      for (var i = 1; i < steps; i++) {
        final lx = r.mx + stepW * i;
        final a = pp(lx, r.my + 0.08);
        final b = pp(lx, r.my + r.mh - 0.08);
        canvas.drawLine(a.x, a.y, b.x, b.y);
        canvas.strokePath();
      }
    } else {
      final stepH = r.mh / steps;
      for (var i = 1; i < steps; i++) {
        final ly = r.my + stepH * i;
        final a = pp(r.mx + 0.08, ly);
        final b = pp(r.mx + r.mw - 0.08, ly);
        canvas.drawLine(a.x, a.y, b.x, b.y);
        canvas.strokePath();
      }
    }
    // Стрелка направления подъёма (по диагонали).
    canvas.setLineWidth(1.0);
    final aArr = pp(r.mx + 0.15, r.my + r.mh - 0.15);
    final bArr = pp(r.mx + r.mw - 0.15, r.my + 0.15);
    canvas.drawLine(aArr.x, aArr.y, bArr.x, bArr.y);
    canvas.strokePath();
  }

  /// Осветлить цвет на [t] (0..1) — линейная интерполяция к белому.
  static PdfColor _lighten(PdfColor c, double t) => PdfColor(
        c.red + (1 - c.red) * t,
        c.green + (1 - c.green) * t,
        c.blue + (1 - c.blue) * t,
      );

  static void _drawCenteredText(
    PdfGraphics canvas,
    String text,
    double cx,
    double cy, {
    required double fontSize,
    required PdfFont font,
  }) {
    final lines = text.split('\n');
    final lineHeight = fontSize * 1.15;
    final totalH = lines.length * lineHeight;
    var y = cy + totalH / 2 - lineHeight;
    canvas.setFillColor(PdfColors.black);
    for (final line in lines) {
      final width = font.stringMetrics(line).width * fontSize;
      canvas.drawString(font, fontSize, line, cx - width / 2, y);
      y -= lineHeight;
    }
  }

  static String _formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year} '
        '${two(d.hour)}:${two(d.minute)}';
  }
}

/// Прямоугольник в модельных координатах (метры, ось Y вниз).
class _RectM {
  final double mx;
  final double my;
  final double mw;
  final double mh;
  const _RectM(this.mx, this.my, this.mw, this.mh);
}
