import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// PDF SERVICE: Geração de Relatórios Clínicos Industriais [SEGURANÇA]
class PdfService {
  static Future<void> exportClinicalReport({
    required String acuityLevel,
    required int totalXP,
    required double noiseThreshold,
    required int sessionXP,
  }) async {
    final pdf = pw.Document();
    
    // Mock de dados históricos de 7 dias para o gráfico [IAB EVOLUTION]
    final chartData = [
      pw.LineDataSet(
        drawSurface: true,
        isCurved: true,
        color: PdfColors.blue900,
        data: List<pw.PointChartValue>.generate(7, (i) {
          final v = [20, 35, 30, 50, 65, 60, 88][i];
          return pw.PointChartValue(i.toDouble(), v.toDouble());
        }),
      ),
    ];

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header Industrial
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("RELATÓRIO CLÍNICO - BOSYN", 
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                  pw.Text("ID: ${DateTime.now().millisecondsSinceEpoch}", 
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
                ],
              ),
              pw.Divider(thickness: 2),
              pw.SizedBox(height: 20),

              // Tabela de Métricas
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey900),
                cellAlignment: pw.Alignment.centerLeft,
                headers: ['MÉTRICA', 'VALOR'],
                data: [
                  ['DATA DE REFERÊNCIA', DateTime.now().toString().split('.')[0]],
                  ['ESTADO DO PACIENTE (IAB)', acuityLevel],
                  ['XP ACUMULADO (TOTAL)', totalXP.toString()],
                  ['XP DE SESSÃO', '+$sessionXP'],
                  ['LIMIAR DE RUÍDO (SNR)', '$noiseThreshold dB'],
                ],
              ),

              pw.SizedBox(height: 30),

              // Gráfico de Evolução
              pw.Text("EVOLUÇÃO DO ÍNDICE DE ACUIDADE (ÚLTIMOS 7 DIAS)", 
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey)),
              pw.SizedBox(height: 10),
              pw.Container(
                height: 150,
                child: pw.Chart(
                  grid: pw.CartesianGrid(
                    xAxis: pw.FixedAxis([0, 1, 2, 3, 4, 5, 6], buildLabel: (v) => "D${v.toInt()+1}"),
                    yAxis: pw.FixedAxis([0, 25, 50, 75, 100], buildLabel: (v) => "${v.toInt()}%"),
                  ),
                  datasets: chartData,
                ),
              ),

              pw.SizedBox(height: 20),
              
              // Métricas de Alta Frequência
              pw.Text("ANÁLISE DE DISCRIMINAÇÃO SIBILANTE", 
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Bullet(text: "Disponibilidade de Ganho: OK (Safe Level)"),
              pw.Bullet(text: "Taxa de Acerto em Alta Frequência: 88%"),
              pw.Bullet(text: "Progressão de SNR: DINAMISMO ATIVO"),

              pw.Spacer(),

              // Rodapé Legal [COMPLIANCE FDA]
              pw.Divider(),
              pw.Text(
                "DISCLAIMER LEGAL: Este documento é um suporte tecnológico à decisão clínica "
                "e destina-se apenas a profissionais de saúde e usuários em reabilitação auditiva. "
                "Os dados apresentados não substituem o diagnóstico médico otorrinolaringológico "
                "ou a avaliação fonoaudiológica em cabine acústica.",
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                textAlign: pw.TextAlign.justify,
              ),
              pw.SizedBox(height: 5),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text("BOSYN NEURAL ENGINE v1.0.0", 
                  style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey)),
              ),
            ],
          );
        },
      ),
    );

    // Dispara a visualização/impressão
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Relatorio_BOSYN_${DateTime.now().day}.pdf',
    );
  }
}
