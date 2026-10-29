# Expiration-date recognition — build 10

## Recognized common formats

| Family | Examples |
| --- | --- |
| Year first | `2027-12-31`, `2027/12/31`, `2027.12.31`, `2027 12 31` |
| Regional numeric | `31/12/2027`, `12/31/2027`, `31.12.27`, `31-12-27` |
| Short year first with printed order hint | `YY/MM/DD: 27/12/31` |
| English month names | `31 DEC 2027`, `31DEC27`, `December 31, 2027`, `2027 DEC 31`, `30 Sept 2027` |
| Arabic Gregorian month names | `31 ديسمبر 2027`, `٣١ كانون الأول ٢٠٢٧` and the other listed month aliases |
| Month and year | `05/2027`, `2027-05`, `05.2027`, `05 2027`, `May 2027`, `MAY27`, `2027 MAY` |
| Date-labelled compact printing | `EXP20271231`, `EXP31052027`, `EXP01072027`, six-digit date alternatives |
| Date-labelled compact month/year | `EXP0527`, `EXP202705`, `EXP052027` |

Numeric separators may have recognition spaces. Arabic-Indic and Persian digits normalize to ASCII. Common dash variants, a trailing sentence period, time suffixes, and directly attached EXP/E/P/BB/BBE/BBD prefixes are supported. Invalid full dates reserve their entire span so fragments cannot be reinterpreted as valid month/year dates.

The parser uses Gregorian years 1900–2199. Two-digit years mean 2000–2099. For separated numeric dates, a two-digit trailing year is the default; year-first order requires a printed `YY/MM/DD` hint. Compact six-digit strings may have several interpretations, which stay selectable. No date format can establish a universally correct regional order without context.

## Expiry versus production

Expiry headings include EXP, expiry/expiration, expires, E, best before/by, BB/BBE/BBD, B.B.E., use by/before, valid until/till, sell by, and common Arabic expiry wording. Sell-by is retained as review-only printed date context; it never fills an expiry automatically.

P, MFG/MFD, manufactured/manufacturing, production/prod, packed/PKD, and common Arabic production/packing wording exclude a date from expiry selection. Mixed/conflicting headings fail closed. Full date options and month options remain distinct.

Vision observations retain geometry. A separate label can identify a date on the same printed row or immediately above an overlapping date. Same-row labels take priority. Distant or equally plausible conflicting labels cannot silently label a date. This handles observations delivered as “Mfg, Exp, production value, expiry value” rather than line order.

## Review rules

- One unambiguous full date can fill automatically when relevant text/label confidence is sufficient. Unrelated low-confidence marketing text does not block it.
- Regional ambiguity such as `01/07/2027` offers both January 7 and July 1. Save waits for selection or manual date entry.
- A month/year date never silently supplies a missing day. The editor shows the month and a clearly labelled **last day of month** option. Choosing it is explicit, including leap-year handling. The selected day is saved using the existing day-based format; a month-precision field is not added to backups.
- OCR digit substitutions such as O→0 and I/l→1 are limited to date-shaped numeric fields under a date label. Corrected interpretations always require review.
- PAO symbols such as `12M`/`24M`, year-only labels, unsupported calendars, and proprietary lot/Julian codes do not generate a guessed expiry date. Opening-relative durations need an opening date; unsupported dates remain manual.

## OCR changes and limits

Vision still runs locally, off the main thread. Minimum text height is set to 0.005 instead of leaving Apple's documented 0.03125 default, so smaller package printing is eligible. If the first pass finds no date, one bounded full-image grayscale/contrast retry is performed. The original photo remains attached. Results from both passes remain available; conflicting dates do not become an automatic choice. Existing normalized-image size limits, generation ownership, and manual-edit protection remain.

Reference: [Apple's minimumTextHeight documentation](https://developer.apple.com/documentation/vision/vnrecognizetextrequest/minimumtextheight).

The two October 17 HEIC attachments were inspected through their color previews. The shampoo label's `Mfg: 06/2025` / `Exp: 05/2027` and the dot-matrix `P:01/07/2024` / `E:01/07/2027` motivated text/geometry regression fixtures. The fixtures are manually transcribed; they are **not** recorded Apple Vision output. No assertion is made that Vision successfully read the original photos in this Windows/WSL environment. The original photos and inspection conversions are not bundled into the app or tests.
