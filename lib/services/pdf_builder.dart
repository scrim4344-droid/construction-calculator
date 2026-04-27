import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/drawing.dart';
import '../models/floor_plan.dart';
import '../models/house_project.dart';

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
    // Преобразование: (mx, my) -> (ox + mx*scale, oy + (planH - my*scale)).
    PdfPoint p(double mx, double my) =>
        PdfPoint(ox + mx * scale, oy + planH - my * scale);

    // Рамка пятна.
    canvas.setStrokeColor(PdfColors.black);
    canvas.setLineWidth(1.5);
    final tl = p(0, 0);
    canvas.drawRect(tl.x, tl.y - planH, planW, planH);
    canvas.strokePath();

    // Комнаты.
    for (final r in plan.rooms) {
      final fillColor = switch (r.kind) {
        PlanRoomKind.staircase => PdfColors.deepPurple50,
        PlanRoomKind.free => PdfColors.amber50,
        PlanRoomKind.room => PdfColors.blue50,
      };
      final strokeColor = switch (r.kind) {
        PlanRoomKind.staircase => PdfColors.deepPurple,
        PlanRoomKind.free => PdfColors.amber700,
        PlanRoomKind.room => PdfColors.blue,
      };
      final tl = p(r.x, r.y);
      final rectW = r.width * scale;
      final rectH = r.height * scale;
      canvas.setFillColor(fillColor);
      canvas.drawRect(tl.x, tl.y - rectH, rectW, rectH);
      canvas.fillPath();
      canvas.setStrokeColor(strokeColor);
      canvas.setLineWidth(0.8);
      canvas.drawRect(tl.x, tl.y - rectH, rectW, rectH);
      canvas.strokePath();
      // Подпись по центру комнаты.
      final cx = ox + (r.x + r.width / 2) * scale;
      final cy = oy + planH - (r.y + r.height / 2) * scale;
      _drawCenteredText(
        canvas,
        '${r.label}\n${r.area.toStringAsFixed(1)} м²',
        cx,
        cy,
        fontSize: rectW > 80 ? 9 : 7,
        font: font,
      );
    }

    // Проёмы.
    for (final o in plan.openings) {
      final color = switch (o.kind) {
        OpeningKind.door => PdfColors.green,
        OpeningKind.externalDoor => PdfColors.red,
        OpeningKind.window => PdfColors.cyan700,
        OpeningKind.archway => PdfColors.grey,
      };
      canvas.setStrokeColor(color);
      canvas.setLineWidth(2.5);
      final PdfPoint a;
      final PdfPoint b;
      if (o.side.isHorizontal) {
        a = p(o.x, o.y);
        b = p(o.x + o.length, o.y);
      } else {
        a = p(o.x, o.y);
        b = p(o.x, o.y + o.length);
      }
      canvas.drawLine(a.x, a.y, b.x, b.y);
      canvas.strokePath();
    }
  }

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
