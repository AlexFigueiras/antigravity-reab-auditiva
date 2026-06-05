import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Gera um relatório em PDF do progresso da pessoa na reabilitação auditiva.
/// Linguagem humana (sem XP/jargão), mas com um aviso clínico honesto — pode ser
/// mostrado ao próprio usuário, a um familiar ou ao fonoaudiólogo.
class PdfService {
  static Future<void> exportClinicalReport({
    /// Como a pessoa está indo, em palavras ("Iniciante", "Intermediário"…).
    required String progressLevel,
    /// Pior nível de ruído já vencido com bom acerto (SNR em dB; menor = mais difícil).
    required double noiseThreshold,
  }) async {
    final pdf = pw.Document();

    // Dados históricos de 7 dias para o gráfico de evolução (exemplo).
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
              // Cabeçalho
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Seu progresso na audição",
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                  pw.Text("BOSYN",
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
                ],
              ),
              pw.Divider(thickness: 2),
              pw.SizedBox(height: 20),

              // Resumo em linguagem simples
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey900),
                cellAlignment: pw.Alignment.centerLeft,
                headers: ['O quê', 'Como está'],
                data: [
                  ['Data deste relatório', DateTime.now().toString().split(' ')[0]],
                  ['Como você está indo', progressLevel],
                  ['Já consegue entender com barulho até', '$noiseThreshold dB de ruído'],
                ],
              ),

              pw.SizedBox(height: 30),

              // Gráfico de evolução
              pw.Text("Como você foi melhorando (últimos 7 dias)",
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey)),
              pw.SizedBox(height: 10),
              pw.Container(
                height: 150,
                child: pw.Chart(
                  grid: pw.CartesianGrid(
                    xAxis: pw.FixedAxis([0, 1, 2, 3, 4, 5, 6], buildLabel: (v) => pw.Text("Dia ${v.toInt()+1}")),
                    yAxis: pw.FixedAxis([0, 25, 50, 75, 100], buildLabel: (v) => pw.Text("${v.toInt()}%")),
                  ),
                  datasets: chartData,
                ),
              ),

              pw.SizedBox(height: 20),

              // Destaques em frases claras
              pw.Text("O que você vem conseguindo",
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Bullet(text: "O som está chegando no volume certo para você."),
              pw.Bullet(text: "Você está acertando bem os sons mais agudos (como S e F)."),
              pw.Bullet(text: "Aos poucos, está entendendo melhor mesmo com barulho de fundo."),

              pw.Spacer(),

              // Aviso clínico honesto
              pw.Divider(),
              pw.Text(
                "Este relatório mostra como você vem treinando e serve de apoio. "
                "Ele não substitui a consulta com o médico otorrinolaringologista "
                "nem a avaliação do fonoaudiólogo em cabine. Em caso de dúvida sobre "
                "sua audição, procure um profissional de saúde.",
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                textAlign: pw.TextAlign.justify,
              ),
              pw.SizedBox(height: 5),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text("BOSYN",
                  style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey)),
              ),
            ],
          );
        },
      ),
    );

    // Abre a visualização/impressão do PDF.
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Meu_progresso_BOSYN_${DateTime.now().day}.pdf',
    );
  }
}
