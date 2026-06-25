import 'package:flutter/material.dart' show BuildContext, ScaffoldMessenger, SnackBar, Text;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReportPdfHelper {
  static Future<void> generateAndPrint({
    required BuildContext context,
    required Map<String, dynamic> salesData,
    required Map<String, dynamic>? expiryData,
    required Map<String, dynamic>? inventoryData,
    required String period,
  }) async {
    try {
      final pdf = pw.Document();

      // Formatter mata uang & angka
      final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
      final numberFormat = NumberFormat.decimalPattern('id_ID');

      // Penerjemahan periode
      String periodText = 'Hari Ini';
      if (period == 'weekly') periodText = 'Minggu Ini';
      if (period == 'monthly') periodText = 'Bulan Ini';
      if (period == 'yearly') periodText = 'Tahun Ini';

      // Definisi warna bertema AppTheme (Clinical Trust)
      final primaryColor = PdfColor.fromInt(0xFF0D5C4A);     // Hijau Tua apotek
      final accentColor = PdfColor.fromInt(0xFFF4A340);      // Amber hangat
      final textColor = PdfColor.fromInt(0xFF1C3D34);        // Teks gelap
      final mutedTextColor = PdfColor.fromInt(0xFF5E8278);   // Teks abu-abu
      final tableHeaderBg = PdfColor.fromInt(0xFFF8FAFC);    // Warna dasar header tabel
      final tableBorder = PdfColor.fromInt(0xFFE2E8F0);      // Garis abu terang

      // 1. Ekstraksi Ringkasan Penjualan
      final summary = salesData['summary'] ?? {};
      final totalRevenue = (summary['totalRevenue'] as num?)?.toDouble() ?? 0.0;
      final totalTransactions = (summary['totalTransactions'] as num?)?.toInt() ?? 0;
      final averageTransaction = (summary['averageTransaction'] as num?)?.toDouble() ?? 0.0;
      final totalItems = (summary['totalItems'] as num?)?.toInt() ?? 0;

      // 2. Ekstraksi Top 10 Obat
      final topDrugs = List<Map<String, dynamic>>.from(salesData['topDrugs'] ?? []);

      // 3. Ekstraksi Metode Pembayaran
      final paymentBreakdown = Map<String, dynamic>.from(salesData['paymentBreakdown'] ?? {});

      // 4. Ekstraksi Data Expired
      final expiredSummary = expiryData != null ? expiryData['summary'] ?? {} : {};
      final expiredCount = (expiredSummary['expiredCount'] as num?)?.toInt() ?? 0;
      final criticalCount = (expiredSummary['criticalCount'] as num?)?.toInt() ?? 0;
      final warningCount = (expiredSummary['warningCount'] as num?)?.toInt() ?? 0;

      // 5. Ekstraksi Distribusi Kategori Inventaris
      final inventoryDrugs = inventoryData != null ? List<Map<String, dynamic>>.from(inventoryData['drugs'] ?? []) : [];
      final categoryCounts = <String, int>{};
      for (final d in inventoryDrugs) {
        final cat = d['category'] as String? ?? 'BEBAS';
        categoryCounts[cat] = (categoryCounts[cat] ?? 0) + 1;
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          header: (pw.Context context) {
            return pw.Column(
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'APOTEKPOS',
                          style: pw.TextStyle(
                            color: primaryColor,
                            fontSize: 22,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          'Laporan Kinerja & Analisis Operasional Apotek',
                          style: pw.TextStyle(
                            color: mutedTextColor,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Periode: $periodText',
                          style: pw.TextStyle(
                            color: textColor,
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Dicetak: ${DateFormat('dd MMMM yyyy, HH:mm', 'id_ID').format(DateTime.now())}',
                          style: pw.TextStyle(
                            color: mutedTextColor,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 6),
                pw.Divider(color: primaryColor, thickness: 1.5),
                pw.SizedBox(height: 12),
              ],
            );
          },
          footer: (pw.Context context) {
            return pw.Container(
              alignment: pw.Alignment.centerRight,
              margin: const pw.EdgeInsets.only(top: 20),
              child: pw.Text(
                'Halaman ${context.pageNumber} dari ${context.pagesCount}',
                style: pw.TextStyle(color: mutedTextColor, fontSize: 8),
              ),
            );
          },
          build: (pw.Context context) {
            return [
              // ===== SECTION 1: KPI CARDS =====
              pw.Text(
                'I. Ringkasan Finansial & Operasional',
                style: pw.TextStyle(color: primaryColor, fontSize: 13, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              
              // Widget Grid Card Pendapatan
              pw.Row(
                children: [
                  _buildPdfCard(
                    title: 'Total Pendapatan',
                    value: currency.format(totalRevenue),
                    primaryColor: primaryColor,
                    textColor: textColor,
                    mutedTextColor: mutedTextColor,
                  ),
                  pw.SizedBox(width: 12),
                  _buildPdfCard(
                    title: 'Total Transaksi',
                    value: numberFormat.format(totalTransactions),
                    primaryColor: primaryColor,
                    textColor: textColor,
                    mutedTextColor: mutedTextColor,
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Row(
                children: [
                  _buildPdfCard(
                    title: 'Rata-rata Transaksi',
                    value: currency.format(averageTransaction),
                    primaryColor: primaryColor,
                    textColor: textColor,
                    mutedTextColor: mutedTextColor,
                  ),
                  pw.SizedBox(width: 12),
                  _buildPdfCard(
                    title: 'Total Item Terjual',
                    value: '${numberFormat.format(totalItems)} pcs',
                    primaryColor: primaryColor,
                    textColor: textColor,
                    mutedTextColor: mutedTextColor,
                  ),
                ],
              ),
              
              pw.SizedBox(height: 20),

              // ===== SECTION 2: TOP 10 OBAT =====
              pw.Text(
                'II. Daftar 10 Besar Obat Terlaris',
                style: pw.TextStyle(color: primaryColor, fontSize: 13, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              
              if (topDrugs.isEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 12),
                  child: pw.Text('Tidak ada data penjualan obat untuk periode ini.', style: pw.TextStyle(color: mutedTextColor, fontSize: 10)),
                )
              else
                pw.Table(
                  border: pw.TableBorder.all(color: tableBorder, width: 0.5),
                  columnWidths: const {
                    0: pw.FixedColumnWidth(30),
                    1: pw.FlexColumnWidth(5),
                    2: pw.FlexColumnWidth(2),
                    3: pw.FlexColumnWidth(3),
                  },
                  children: [
                    // Header Row
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: tableHeaderBg),
                      children: [
                        _buildTableHeaderCell('#', textColor),
                        _buildTableHeaderCell('Nama Obat', textColor),
                        _buildTableHeaderCell('Terjual', textColor),
                        _buildTableHeaderCell('Total Penjualan', textColor),
                      ],
                    ),
                    // Data Rows
                    ...topDrugs.asMap().entries.map((entry) {
                      final index = entry.key;
                      final drug = entry.value;
                      final revenueVal = (drug['revenue'] as num?)?.toDouble() ?? 0.0;
                      final qtyVal = (drug['quantity'] as num?)?.toInt() ?? 0;
                      return pw.TableRow(
                        children: [
                          _buildTableCell('${index + 1}', textColor, alignRight: false),
                          _buildTableCell(drug['name'] ?? '-', textColor, alignRight: false),
                          _buildTableCell('$qtyVal pcs', textColor, alignRight: true),
                          _buildTableCell(currency.format(revenueVal), textColor, alignRight: true),
                        ],
                      );
                    }),
                  ],
                ),

              pw.SizedBox(height: 20),

              // ===== SECTION 3: METODE PEMBAYARAN =====
              pw.Text(
                'III. Analisis Metode Pembayaran',
                style: pw.TextStyle(color: primaryColor, fontSize: 13, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              
              if (paymentBreakdown.isEmpty)
                pw.Text('Tidak ada data pembayaran.', style: pw.TextStyle(color: mutedTextColor, fontSize: 10))
              else
                pw.Table(
                  border: pw.TableBorder.all(color: tableBorder, width: 0.5),
                  columnWidths: const {
                    0: pw.FlexColumnWidth(5),
                    1: pw.FlexColumnWidth(3),
                  },
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: tableHeaderBg),
                      children: [
                        _buildTableHeaderCell('Metode Pembayaran', textColor),
                        _buildTableHeaderCell('Nominal', textColor),
                      ],
                    ),
                    ...paymentBreakdown.entries.map((e) {
                      final val = (e.value as num?)?.toDouble() ?? 0.0;
                      return pw.TableRow(
                        children: [
                          _buildTableCell(e.key.toUpperCase(), textColor, alignRight: false),
                          _buildTableCell(currency.format(val), textColor, alignRight: true),
                        ],
                      );
                    }),
                  ],
                ),

              pw.SizedBox(height: 20),

              // ===== SECTION 4: EXPIRED & INVENTARIS =====
              pw.Text(
                'IV. Status Inventaris & Kadaluarsa Obat',
                style: pw.TextStyle(color: primaryColor, fontSize: 13, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Box status kadaluarsa
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: tableBorder, width: 0.5),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Status Kadaluarsa', style: pw.TextStyle(color: textColor, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                          pw.SizedBox(height: 6),
                          _buildStatusRow('Sudah Kadaluarsa', '$expiredCount batch', accentColor),
                          pw.SizedBox(height: 4),
                          _buildStatusRow('Kritis (< 30 hari)', '$criticalCount batch', accentColor),
                          pw.SizedBox(height: 4),
                          _buildStatusRow('Perhatian (< 90 hari)', '$warningCount batch', mutedTextColor),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 16),
                  
                  // Box kategori inventaris
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: tableBorder, width: 0.5),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Persebaran Kategori', style: pw.TextStyle(color: textColor, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                          pw.SizedBox(height: 6),
                          if (categoryCounts.isEmpty)
                            pw.Text('Belum ada data obat', style: pw.TextStyle(color: mutedTextColor, fontSize: 9))
                          else
                            ...categoryCounts.entries.map((e) {
                              final displayCat = e.key.replaceAll('_', ' ');
                              return pw.Padding(
                                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                                child: _buildStatusRow(displayCat, '${e.value} jenis', textColor),
                              );
                            }),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ];
          },
        ),
      );

      // Jalankan pratinjau cetak PDF
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'laporan_apotek_${period}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengekspor PDF: $e')),
        );
      }
    }
  }

  // Helper widget PdfCard
  static pw.Widget _buildPdfCard({
    required String title,
    required String value,
    required PdfColor primaryColor,
    required PdfColor textColor,
    required PdfColor mutedTextColor,
  }) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromInt(0xFFF8FAFA), // Latar kartu abu-hijau pucat
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          border: pw.Border.all(color: PdfColor.fromInt(0xFFD1E8E4), width: 0.5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(color: mutedTextColor, fontSize: 9),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(
                color: primaryColor,
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper text table header
  static pw.Widget _buildTableHeaderCell(String text, PdfColor color) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          fontSize: 9,
          color: color,
        ),
      ),
    );
  }

  // Helper text table data cell
  static pw.Widget _buildTableCell(String text, PdfColor color, {required bool alignRight}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Container(
        alignment: alignRight ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 9,
            color: color,
          ),
        ),
      ),
    );
  }

  // Helper status bar
  static pw.Widget _buildStatusRow(String label, String value, PdfColor valueColor) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 9,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
