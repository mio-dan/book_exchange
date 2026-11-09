# Buchtausch-App – Relationale Datenbank

## Projektbeschreibung

Im Rahmen eines Portfolios wurde eine relationale Datenbank für eine Buchtausch-App entwickelt und in MySQL umgesetzt. Die Datenbank dient zur Verwaltung von Benutzer:innen, Büchern, Buchexemplaren und Ausleihvorgängen.

## Datenbankstruktur

Die Datenbank „book_exchange“ besteht aus zwölf miteinander verknüpften Tabellen. Die Beziehungen werden über Primär- und Fremdschlüssel abgebildet. Für die N:M-Beziehungen zwischen Büchern und Autor:innen sowie zwischen Büchern und Genres werden die Zwischentabellen BookAuthor und BookGenre verwendet.

## Datenintegrität und Verfügbarkeit

Zur Sicherstellung der Datenintegrität wurden CHECK- und UNIQUE-Constraints sowie acht Trigger implementiert. Zusätzlich ermittelt die View „BookCopyAvailability“ die Verfügbarkeit einzelner Buchexemplare anhand der gespeicherten Ausleihvorgänge.

## Installation

1. MySQL Server und MySQL Workbench bereitstellen.
2. Die Datei `book_exchange.sql` in MySQL Workbench öffnen.
3. Das SQL-Skript vollständig ausführen.

Das Skript erstellt die Datenbank „book_exchange“ einschließlich der Tabellen, Integritätsbedingungen, Trigger und View.

## Testdaten und SQL-Abfragen

Das SQL-Skript enthält für jede der zwölf Tabellen zehn Testdatensätze. Zusätzlich sind SQL-Abfragen mit JOIN-Operationen enthalten, mit denen die Beziehungen zwischen den Tabellen überprüft werden können.
