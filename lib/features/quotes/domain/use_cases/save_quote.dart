import '../models/quote.dart';
import '../repositories/quote_repository.dart';

class SaveQuote {
  const SaveQuote(this.repository);

  final QuoteRepository repository;

  Future<Quote> call(Quote quote) {
    if (quote.customerName.trim().isEmpty) {
      throw const FormatException('Inserisci il nome del cliente.');
    }
    if (quote.lines.isEmpty) {
      throw const FormatException('Aggiungi almeno una voce al preventivo.');
    }
    if (quote.validityDays < 1 || quote.validityDays > 3650) {
      throw const FormatException('Validità non ammessa.');
    }
    if (quote.discountBasisPoints < 0 || quote.discountBasisPoints > 10000) {
      throw const FormatException('Sconto non ammesso.');
    }
    for (final line in quote.lines) {
      if (line.description.trim().isEmpty ||
          line.quantityMilli <= 0 ||
          line.unitPriceCents < 0 ||
          !const {0, 4, 10, 22}.contains(line.vatRate)) {
        throw const FormatException('Controlla le voci del preventivo.');
      }
    }
    return repository.save(quote);
  }
}
