#!/usr/bin/env python3
"""
CSV to HTML Report Generator
Creates a mobile-friendly HTML page with tabs for each CSV file in the directory.
"""

from __future__ import annotations

import csv
import json
import os
from pathlib import Path
from typing import List, Dict, Any
import html
from collections import Counter
from datetime import datetime, timedelta
import pytz
from os.path import expanduser
import math
import builtins
import argparse
import shutil
import subprocess

from reporting.pointer import extract_ranking_user_id
from reporting.models import FestivalConfig
from reporting.naming import dashboard_title

_FESTIVAL_CONTEXT: FestivalConfig | None = None


def set_festival_context(config: FestivalConfig) -> None:
    global _FESTIVAL_CONTEXT, TOTAL_USER_BASE_FOR_ATTENDANCE
    _FESTIVAL_CONTEXT = config
    TOTAL_USER_BASE_FOR_ATTENDANCE = config.total_user_base_for_attendance


# ============================================================================
# CONFIGURATION CONSTANTS
# ============================================================================

# Total user base for event attendance estimation
TOTAL_USER_BASE_FOR_ATTENDANCE = 2920

# ============================================================================

def open_csv_robust(file_path, mode='r'):
    """
    Open a CSV file with multiple encoding attempts to handle encoding issues.
    Tries different encodings and falls back to error replacement if all fail.
    """
    encodings = ['utf-8', 'latin-1', 'cp1252', 'iso-8859-1']
    
    for encoding in encodings:
        try:
            return open(file_path, mode, encoding=encoding)
        except UnicodeDecodeError:
            continue
    
    # If all encodings fail, use the replace method as fallback
    return open(file_path, mode, encoding='utf-8', errors='replace')

def open_csv_robust_with_fallback(file_path, mode='r'):
    """
    Enhanced version that tries to detect and handle mixed encodings.
    Specifically handles cases where files contain Latin-1 characters in UTF-8 context.
    """
    try:
        # First try UTF-8
        return open(file_path, mode, encoding='utf-8')
    except UnicodeDecodeError as e:
        # If UTF-8 fails, try to read as Latin-1 and convert
        try:
            with open(file_path, mode, encoding='latin-1') as f:
                content = f.read()
            # Convert Latin-1 content to UTF-8
            content_utf8 = content.encode('latin-1').decode('utf-8', errors='replace')
            # Create a temporary file-like object with the converted content
            import io
            return io.StringIO(content_utf8)
        except Exception:
            # Final fallback: use replace method
            return open(file_path, mode, encoding='utf-8', errors='replace')

# ============================================================================
# CONFIGURATION - File paths and URLs
# ============================================================================

def get_file_paths(source: str = '70k') -> dict:
    """Get file paths from the active festival context."""
    if _FESTIVAL_CONTEXT is None:
        raise RuntimeError(
            "Festival context not set. Call set_festival_context() before generating reports."
        )
    config = _FESTIVAL_CONTEXT
    return {
        'static_files': {
            'eventData': str(config.event_data_csv),
            'rankingData': str(config.ranking_data_csv),
            'userData': str(config.user_data_csv),
            'bandsData': str(config.json_backup_path),
        },
        'artist_lineup': str(config.artist_lineup_path or ''),
        'artist_schedule': str(config.artist_schedule_path or ''),
        'event_year': config.event_year,
        'pointer_path': str(config.pointer_path),
        'output_main': config.reports_main,
        'output_full': config.reports_full,
        'language_files': dict(config.reports_languages),
    }

# Default configuration (for backward compatibility)
STATIC_FILES = {}

# Template file
HTML_TEMPLATE_FILE = str(
    Path(__file__).resolve().parent / 'templates' / 'report_template.html'
)

# ============================================================================
# END CONFIGURATION
# ============================================================================

# Translation dictionaries for language-specific versions
TRANSLATIONS = {
    'en': {
        'Stats': 'Stats',
        'Band Rankings': 'Band Rankings',
        'Countries': 'Countries',
        'Platforms': 'Platforms',
        'Band Name': 'Band Name',
        '% Must': '% Must',
        'Must': 'Must',
        'Country': 'Country',
        '% Of Users': '% Of Users',
        'User Count': 'User Count',
        'Platform': 'Platform',
        'Total': 'Total',
        'Report generated:': 'Report generated:',
        'No data available': 'No data available',
        'Last updated:': 'Last updated:',
        'Showing top': 'Showing top',
        'entries only': 'entries only',
        'Tap/click truncated names to see full text': 'Tap/click truncated names to see full text',
        'All data based on users who have used the app in the last 30 days.': 'All data based on users who have used the app in the last 30 days.',
        'The total used for the percentage calculation is based on the number of Must, Might, and Wont votes a band received.': 'The total used for the percentage calculation is based on the number of Must, Might, and Wont votes a band received.',
        'The app is being used by users in {{n}} countries.': 'The app is being used by users in {{n}} countries.',
    },
    'da': {
        'Stats': 'Statistik',
        'Band Rankings': 'Top Bands',
        'Countries': 'Lande',
        'Platforms': 'Platforme',
        'Band Name': 'Bandnavn',
        '% Must': '% Skal',
        'Must': 'Skal',
        'Country': 'Land',
        '% Of Users': '% af brugere',
        'User Count': 'Brugerantal',
        'Platform': 'Platform',
        'Total': 'Total',
        'Report generated:': 'Rapport genereret:',
        'No data available': 'Ingen data tilgængelig',
        'Last updated:': 'Sidst opdateret:',
        'Showing top': 'Viser top',
        'entries only': 'poster kun',
        'Tap/click truncated names to see full text': 'Tryk/klik på afkortede navne for at se fuld tekst',
        'All data based on users who have used the app in the last 30 days.': 'Alle data er baseret på brugere, der har brugt appen inden for de sidste 30 dage.',
        'The total used for the percentage calculation is based on the number of Must, Might, and Wont votes a band received.': 'Det samlede antal, der bruges til procentberegningen, er baseret på antallet af Must, Might og Wont-stemmer, et band har modtaget.',
        'The app is being used by users in {{n}} countries.': 'Appen bruges af brugere i {{n}} lande.',
    },
    'de': {
        'Stats': 'Statistiken',
        'Band Rankings': 'Band-Rangliste',
        'Countries': 'Länder',
        'Platforms': 'Plattformen',
        'Band Name': 'Bandname',
        '% Must': '% Muss',
        'Must': 'Muss',
        'Country': 'Land',
        '% Of Users': '% der Nutzer',
        'User Count': 'Nutzeranzahl',
        'Platform': 'Plattform',
        'Total': 'Gesamt',
        'Report generated:': 'Bericht erstellt:',
        'No data available': 'Keine Daten verfügbar',
        'Last updated:': 'Zuletzt aktualisiert:',
        'Showing top': 'Zeige Top',
        'entries only': 'Einträge',
        'Tap/click truncated names to see full text': 'Tippen/Klicken Sie auf gekürzte Namen, um den vollständigen Text anzuzeigen',
        'All data based on users who have used the app in the last 30 days.': 'Alle Daten basieren auf Nutzern, die die App in den letzten 30 Tagen verwendet haben.',
        'The total used for the percentage calculation is based on the number of Must, Might, and Wont votes a band received.': 'Die Gesamtzahl für die Prozentberechnung basiert auf der Anzahl der Must-, Might- und Wont-Stimmen, die eine Band erhalten hat.',
        'The app is being used by users in {{n}} countries.': 'Die App wird von Nutzern in {{n}} Ländern verwendet.',
    },
    'es': {
        'Stats': 'Estadísticas',
        'Band Rankings': 'Ranking de bandas',
        'Countries': 'Países',
        'Platforms': 'Plataformas',
        'Band Name': 'Nombre de la banda',
        '% Must': '% Debe',
        'Must': 'Debe',
        'Country': 'País',
        '% Of Users': '% de usuarios',
        'User Count': 'Cantidad de usuarios',
        'Platform': 'Plataforma',
        'Total': 'Total',
        'Report generated:': 'Informe generado:',
        'No data available': 'No hay datos disponibles',
        'Last updated:': 'Última actualización:',
        'Showing top': 'Mostrando los',
        'entries only': 'primeros registros',
        'Tap/click truncated names to see full text': 'Toque/haga clic en los nombres truncados para ver el texto completo',
        'All data based on users who have used the app in the last 30 days.': 'Todos los datos se basan en usuarios que han utilizado la aplicación en los últimos 30 días.',
        'The total used for the percentage calculation is based on the number of Must, Might, and Wont votes a band received.': 'El total utilizado para el cálculo del porcentaje se basa en el número de votos Must, Might y Wont que recibió una banda.',
        'The app is being used by users in {{n}} countries.': 'La aplicación está siendo utilizada por usuarios en {{n}} países.',
    },
    'fi': {
        'Stats': 'Tilastot',
        'Band Rankings': 'Bändien sijoitukset',
        'Countries': 'Maat',
        'Platforms': 'Alustat',
        'Band Name': 'Bändin nimi',
        '% Must': '% Pakko',
        'Must': 'Pakko',
        'Country': 'Maa',
        '% Of Users': 'Käyttäjien %',
        'User Count': 'Käyttäjämäärä',
        'Platform': 'Alusta',
        'Total': 'Yhteensä',
        'Report generated:': 'Raportti luotu:',
        'No data available': 'Ei tietoja saatavilla',
        'Last updated:': 'Viimeksi päivitetty:',
        'Showing top': 'Näytetään parhaat',
        'entries only': 'merkintää',
        'Tap/click truncated names to see full text': 'Napauta/klikkaa lyhennettyjä nimiä nähdäksesi koko tekstin',
        'All data based on users who have used the app in the last 30 days.': 'Kaikki tiedot perustuvat käyttäjiin, jotka ovat käyttäneet sovellusta viimeisten 30 päivän aikana.',
        'The total used for the percentage calculation is based on the number of Must, Might, and Wont votes a band received.': 'Prosenttilaskennassa käytetty kokonaismäärä perustuu bändin saamiin Must, Might ja Wont -ääniin.',
        'The app is being used by users in {{n}} countries.': 'Sovellusta käyttää käyttäjiä {{n}} maassa.',
    },
    'fr': {
        'Stats': 'Statistiques',
        'Band Rankings': 'Classement des groupes',
        'Countries': 'Pays',
        'Platforms': 'Plateformes',
        'Band Name': 'Nom du groupe',
        '% Must': '% Doit',
        'Must': 'Doit',
        'Country': 'Pays',
        '% Of Users': '% des utilisateurs',
        'User Count': "Nombre d'utilisateurs",
        'Platform': 'Plateforme',
        'Total': 'Total',
        'Report generated:': 'Rapport généré :',
        'No data available': 'Aucune donnée disponible',
        'Last updated:': 'Dernière mise à jour :',
        'Showing top': 'Affichage des',
        'entries only': 'premières entrées',
        'Tap/click truncated names to see full text': 'Appuyez/cliquez sur les noms tronqués pour voir le texte complet',
        'All data based on users who have used the app in the last 30 days.': 'Toutes les données sont basées sur les utilisateurs ayant utilisé l\'application au cours des 30 derniers jours.',
        'The total used for the percentage calculation is based on the number of Must, Might, and Wont votes a band received.': 'Le total utilisé pour le calcul du pourcentage est basé sur le nombre de votes Must, Might et Wont qu\'un groupe a reçus.',
        'The app is being used by users in {{n}} countries.': 'L\'application est utilisée par des utilisateurs dans {{n}} pays.',
    },
    'pt': {
        'Stats': 'Estatísticas',
        'Band Rankings': 'Ranking de bandas',
        'Countries': 'Países',
        'Platforms': 'Plataformas',
        'Band Name': 'Nome da banda',
        '% Must': '% Deve',
        'Must': 'Deve',
        'Country': 'País',
        '% Of Users': '% de usuários',
        'User Count': 'Contagem de usuários',
        'Platform': 'Plataforma',
        'Total': 'Total',
        'Report generated:': 'Relatório gerado:',
        'No data available': 'Nenhum dado disponível',
        'Last updated:': 'Última atualização:',
        'Showing top': 'Mostrando os',
        'entries only': 'principais registros',
        'Tap/click truncated names to see full text': 'Toque/clique em nomes truncados para ver o texto completo',
        'All data based on users who have used the app in the last 30 dias.': 'Todos os dados são baseados em usuários que usaram o aplicativo nos últimos 30 dias.',
        'The total used for the percentage calculation is based on the number of Must, Might, and Wont votes a band received.': 'O total usado para o cálculo da porcentagem é baseado no número de votos Must, Might e Wont que uma banda recebeu.',
        'The app is being used by users in {{n}} countries.': 'O aplicativo está sendo usado por usuários em {{n}} países.',
    },
}

def band_display_cap(announced_band_count: int) -> int:
    """
    Cap visible band rankings in steps of 5 (max 20), based on announced
    lineup size. Fewer than 10 announced bands show nothing — too small a
    lineup to rank without highlighting least favorites.
    """
    if announced_band_count < 10:
        return 0
    return min(20, (announced_band_count // 10) * 5)


def load_valid_bands_from_lineup(source: str = '70K_Bands') -> set[str]:
    """
    Load the set of valid band names from the artist lineup file.
    
    Args:
        source: Data source ('70K_Bands' or 'MDF_Bands')
    
    Returns:
        Set of valid band names (case-insensitive)
    """
    valid_bands = set()
    file_paths = get_file_paths(source)
    artist_lineup_file = Path(file_paths['artist_lineup'])
    
    if not artist_lineup_file.exists():
        print(f"Warning: Artist lineup file not found at {artist_lineup_file}")
        return valid_bands
    
    try:
        with open_csv_robust_with_fallback(artist_lineup_file) as f:
            reader = csv.DictReader(f)
            for row in reader:
                band_name = row.get('bandName', '').strip()
                if band_name:
                    # Store in lowercase for case-insensitive comparison
                    valid_bands.add(band_name.lower())
        
        print(f"Loaded {len(valid_bands)} valid bands from artist lineup file")
        # Debug: Print first 10 bands to verify loading
        print(f"Sample bands loaded: {list(valid_bands)[:10]}")
        return valid_bands
    except Exception as e:
        print(f"Error loading artist lineup file: {e}")
        return valid_bands


def is_valid_band(band_name: str, valid_bands: set[str]) -> bool:
    """
    Check if a band name is in the valid bands list.
    
    Args:
        band_name: The band name to check
        valid_bands: Set of valid band names (lowercase)
    
    Returns:
        True if the band is valid, False otherwise
    """
    return band_name.lower() in valid_bands


def read_csv_file(file_path: Path) -> tuple[List[str], List[Dict[str, Any]]]:
    """
    Read a CSV file and return headers and data.
    
    Args:
        file_path: Path to the CSV file
        
    Returns:
        Tuple of (headers, data_rows)
    """
    headers = []
    data = []
    
    try:
        with open_csv_robust(file_path) as file:
            csv_reader = csv.reader(file)
            all_headers = next(csv_reader)  # Get the header row
            
            # For eventCountReport.csv, filter to only Event and totalPercentage columns
            if file_path.name == 'eventCountReport.csv':
                # Find the indices of the columns we want to keep
                event_index = None
                total_percentage_index = None
                
                for i, header in enumerate(all_headers):
                    if header == 'Event':
                        event_index = i
                    elif header == 'totalPercentage':
                        total_percentage_index = i
                
                if event_index is not None and total_percentage_index is not None:
                    headers = ['Event', 'Total Percentage']
                    # Read all data rows and filter columns
                    for row in csv_reader:
                        if row:  # Skip empty rows
                            filtered_row = [row[event_index], row[total_percentage_index]]
                            data.append(filtered_row)
                else:
                    # Fallback to all columns if the specific ones aren't found
                    headers = all_headers
                    for row in csv_reader:
                        if row:  # Skip empty rows
                            data.append(row)
            # For bandCountReport.csv, reorder columns to put Band first, then percentages
            elif file_path.name == 'bandCountReport.csv':
                # Define the desired column order
                desired_columns = ['Band', 'Must%', 'Might%', 'Wont%', 'Must', 'Might', 'Wont']
                
                # Create a mapping of column names to their indices
                column_indices = {header: i for i, header in enumerate(all_headers)}
                
                # Create new headers and reorder data
                headers = desired_columns
                for row in csv_reader:
                    if row:  # Skip empty rows
                        # Reorder the row according to desired column order
                        reordered_row = [row[column_indices[col]] for col in desired_columns]
                        data.append(reordered_row)
            else:
                # For all other files, use all columns
                headers = all_headers
                for row in csv_reader:
                    if row:  # Skip empty rows
                        data.append(row)
                    
    except Exception as e:
        print(f"Error reading {file_path}: {e}")
        return [], []
    
    return headers, data


def escape_html(text: str) -> str:
    """
    Escape HTML special characters in a string.
    
    Args:
        text: The text to escape
    
    Returns:
        The escaped string
    """
    return html.escape(str(text))


def format_number(value: str) -> str:
    """
    Format a string as a number with commas for readability.
    
    Args:
        value: The value to format
    
    Returns:
        The formatted string, or the original value if not a number
    """
    try:
        num = float(value)
        if num.is_integer():
            return f"{int(num):,}"
        return f"{num:,.2f}"
    except (ValueError, TypeError):
        return value


def format_cell_value(value: str, header: str) -> str:
    """
    Format a cell value, adding percentage signs to numeric values in percentage columns.
    
    Args:
        value: The cell value to format
        header: The column header name
    
    Returns:
        The formatted cell value
    """
    # Handle empty or None values
    if not value or not str(value).strip():
        return ''
    
    # Check if header contains "percent" or ends with "%" (case insensitive)
    if ('percent' in header.lower() or header.strip().endswith('%')) and value.strip():
        try:
            # Try to parse as number and add % if it's numeric and doesn't already have %
            num = float(value.strip().rstrip('%'))
            if not value.strip().endswith('%'):
                return f"{round(num)}%"
            else:
                # If it already has %, also round it
                return f"{round(num)}%"
        except (ValueError, TypeError):
            pass
    
    # Apply standard number formatting
    return format_number(value)


def get_file_modification_date(file_path: Path) -> tuple[str, int]:
    """
    Get the last modification date of a file in the user's local timezone.
    
    Args:
        file_path: Path to the file
    
    Returns:
        Tuple of (formatted modification date string in local timezone, epoch timestamp)
    """
    try:
        timestamp = os.path.getmtime(file_path)
        epoch = int(timestamp)
        
        # Create datetime object in local timezone
        local_date = datetime.fromtimestamp(timestamp)
        
        # Try to get timezone name using multiple approaches
        try:
            # First try to use the system's timezone
            import time
            is_dst = time.daylight and time.localtime(timestamp).tm_isdst > 0
            timezone_name = time.tzname[is_dst]
        except (IndexError, OSError):
            # Fallback to a simpler approach
            timezone_name = local_date.strftime('%Z')
            if not timezone_name:
                # If no timezone name available, show UTC offset
                timezone_name = local_date.strftime('%z')
                if timezone_name:
                    # Format UTC offset nicely (e.g., +0500 -> +05:00)
                    timezone_name = f"UTC{timezone_name[:3]}:{timezone_name[3:]}"
                else:
                    timezone_name = "UTC"  # Default to UTC if unable to determine
        
        # Format with local timezone indicator
        formatted_date = local_date.strftime(f"%B %d, %Y at %I:%M %p {timezone_name}")
        return (formatted_date, epoch)
    except Exception:
        # Return current time as fallback
        now_epoch = int(datetime.now().timestamp())
        return ("Unknown", now_epoch)


def format_title(text: str) -> str:
    """
    Format a title by splitting on internal capitalization, capitalizing words, and removing suffixes.
    
    Args:
        text: The text to format
    
    Returns:
        Formatted title string
    """
    # Handle special case renames first
    if text == 'bandCountReport.csv':
        return 'Top Bands'
    elif text == 'eventCountReport.csv':
        return 'Top Events'
    
    # Remove .csv extension and Report suffix
    text = text.replace('.csv', '').replace('Report', '')
    
    # Split on internal caps and handle special cases
    words = []
    current_word = ""
    
    for i, char in enumerate(text):
        if i > 0 and char.isupper():
            # If we have a current word, add it to our list
            if current_word:
                words.append(current_word)
            current_word = char
        else:
            current_word += char
    
    # Add the last word
    if current_word:
        words.append(current_word)
    
    # Capitalize first letter of each word
    words = [word.capitalize() for word in words]
    
    return " ".join(words)


def generate_html_content(csv_files: List[tuple[str, List[str], List[Dict[str, Any]], str]], last_generated: str, limit_country_rows: bool = True) -> str:
    """
    Generate the complete HTML content for the dashboard using a template.
    
    Args:
        csv_files: List of tuples containing filename, headers, data, and modification date
        last_generated: Timestamp string for when the report was generated
        limit_country_rows: Whether to limit the number of country rows shown
    
    Returns:
        The generated HTML content as a string
    """
    def generate_tab_button(tab_id, tab_name, is_first=False, en_name=None):
        active_class = ' active' if is_first else ''
        data_en = f' data-en="{en_name or tab_name}"'
        
        # Add icons to tab names
        icon_map = {
            'Band Rankings': '🎵',
            'Countries': '🌍', 
            'Platforms': '📱',
            'Band Country': '🏁',
            'Band Repeats': '🔄',
            'Top Band by Country': '🏆',
            'Platform by Country': '🌐',
            'Event Attendance': '🎫',
            'Daily Usage': '📊',
            'Monthly Usage': '📅',
            'OS Version': '⚙️',
            '70K Version': '📲'
        }
        
        icon = icon_map.get(en_name or tab_name, '')
        display_name = f"{icon} {tab_name}" if icon else tab_name
        
        return f'<button class="tab-button{active_class}" onclick="openTab(event, \'{tab_id}\')"{data_en}>{display_name}</button>'

    def generate_tab_content(tab_id, content, is_first=False):
        display_style = 'block' if is_first else 'none'
        return f'<div id="{tab_id}" class="tab-content" style="display: {display_style}">{content}</div>'

    def generate_table_html(headers, data, filename=None, mod_date=None, original_data_len=None, limit_country_rows: bool = True):
        print(f"[DEBUG] generate_table_html called: filename={filename}, limit_country_rows={limit_country_rows}")
        table_html = '<div style="overflow-x: auto;">\n'
        # Add file modification date if available
        if mod_date:
            # Handle both tuple (formatted_string, epoch) and plain string formats
            if isinstance(mod_date, tuple) and len(mod_date) == 2:
                formatted_date, epoch = mod_date
                table_html += f'<div style="color: #888; margin-bottom: 10px; font-size: 12px; font-style: italic;">Last updated: <span data-timestamp="{epoch}">{formatted_date}</span></div>\n'
            else:
                # Backward compatibility: plain string
                table_html += f'<div style="color: #888; margin-bottom: 10px; font-size: 12px; font-style: italic;">Last updated: {mod_date}</div>\n'
        
        # Add note about data limitation if applicable
        if original_data_len is not None:
            # For Country/Platform, exclude total row from count
            if filename and filename.strip().lower() in ('countryreport.csv', 'country report'):
                shown = len(data) - 1 if len(data) > 0 else 0
                orig = original_data_len - 1 if original_data_len > 0 else 0
            else:
                shown = len(data)
                orig = original_data_len
            if shown < orig:
                table_html += f'<div class="showing-top-note" data-n="{shown}" style="color: #888; margin-bottom: 10px; font-style: italic;">Showing top {shown} entries only</div>\n'
        # Always add country count note for Country Report (both standard and full reports)
        if filename and filename.strip().lower() in ('countryreport.csv', 'country report'):
            num_countries = getattr(builtins, 'country_count_unique', None)
            if num_countries is not None:
                note_template = 'The app is being used by users in {{n}} countries.'
                note_text = f'The app is being used by users in {num_countries} countries.'
                table_html += f'<div class="country-count-note" data-en="{note_template}" style="color: #888; margin-bottom: 10px; font-style: italic;">{note_text}</div>\n'
        
        table_html += '<table class="data-table">\n'
        
        # Generate headers
        table_html += '<thead>\n<tr>\n'
        
        # Handle different reports
        if filename and filename.strip().lower() in ('countryreport.csv', 'country report'):
            # Helper to find header index robustly
            def find_header_idx(header_options):
                for opt in header_options:
                    for i, h in enumerate(headers):
                        if h.strip().lower() == opt.strip().lower():
                            return i
                raise ValueError(f"None of {header_options} found in headers: {headers}")
            # For country report, show Rank, Country, Percentage, User Count
            country_headers = ['Rank', 'Country', 'Percentage', 'User Count']
            for header in country_headers:
                
                title_attr = ' title="Tap/click truncated names to see full text"' if header == 'Country' else ''
                table_html += f'<th data-en="{header}"{title_attr}>{escape_html(header)}</th>\n'
            # Robust header index lookup
            country_idx = find_header_idx(['Country'])
            percentage_idx = find_header_idx(['Percentage', '% of Users'])
            user_count_idx = find_header_idx(['User Count'])
        elif filename == 'bandCountReport.csv':
            # For band count report, only include Rank, Band, % Must, and Must columns
            selected_headers = ['Rank', 'Band', '% Must', 'Must']
            for header in selected_headers:
                table_html += f'<th data-en="{header}">{escape_html(header)}</th>\n'
        elif filename == 'eventCountReport.csv' or filename == 'Event Attendance':
            # For event count report / Event Attendance, show Event, % Attended, # Attended, Total Users, Est. Attendance
            new_headers = ['Event', '% Attended', '# Attended', 'Total Users', 'Est. Attendance']
            for header in new_headers:
                title_attr = ' title="Tap/click truncated names to see full text"' if header == 'Event' else ''
                table_html += f'<th data-en="{header}"{title_attr}>{escape_html(header)}</th>\n'
        elif filename == 'platformReport.csv' or filename == 'Platform Report':
            # For platform report, show Platform, % of Users, User Count  
            platform_headers = ['Platform', '% of Users', 'User Count']
            for header in platform_headers:
                table_html += f'<th data-en="{header}">{escape_html(header)}</th>\n'
        else:
            for header in headers:
                table_html += f'<th data-en="{header}">{escape_html(header)}</th>\n'
        table_html += '</tr>\n</thead>\n'
        
        # Generate body
        table_html += '<tbody>\n'
        
        # Handle sorting and data preparation
        if filename and filename.strip().lower() in ('countryreport.csv', 'country report'):
            # Country report sorting logic - reorder to Country, Percentage, User Count
            
            total_row = None
            other_data = []
            for row in data:
                if row[country_idx] == 'Total':
                    total_row = row
                else:
                    other_data.append(row)
            
            # Create new rows with reordered columns and add country flags
            country_flags = {
                'United States': '🇺🇸', 'Canada': '🇨🇦', 'Germany': '🇩🇪', 'Switzerland': '🇨🇭',
                'Finland': '🇫🇮', 'Netherlands': '🇳🇱', 'France': '🇫🇷', 'Mexico': '🇲🇽',
                'Belgium': '🇧🇪', 'Colombia': '🇨🇴', 'Austria': '🇦🇹', 'Costa Rica': '🇨🇷',
                'Norway': '🇳🇴', 'Australia': '🇦🇺', 'Hungary': '🇭🇺', 'Puerto Rico': '🇵🇷',
                'Brazil': '🇧🇷', 'Greece': '🇬🇷', 'Czech Republic': '🇨🇿', 'Tunisia': '🇹🇳',
                'Sweden': '🇸🇪', 'Italy': '🇮🇹', 'United Kingdom': '🇬🇧', 'Denmark': '🇩🇰',
                'Andorra': '🇦🇩', 'Faroe Islands': '🇫🇴', 'Poland': '🇵🇱', 'Chile': '🇨🇱',
                'Ukraine': '🇺🇦', 'Japan': '🇯🇵', 'Portugal': '🇵🇹', 'International': '🌍'
            }
            processed_data = []
            for row in other_data:
                country_name = row[country_idx]
                flag = country_flags.get(country_name, '')
                display_name = f"{flag} {country_name}" if flag else country_name
                processed_data.append([
                    display_name,
                    format_cell_value(row[percentage_idx], 'Percentage'),
                    row[user_count_idx]
                ])
            # Debug: print how many countries before and after limiting
            print(f"[DEBUG] Country Report: limit_country_rows={limit_country_rows}, total countries before limiting: {len(processed_data)}")
            # Sort by user count descending, then by country name
            sorted_data = sorted(processed_data, key=lambda x: (-int(x[2]), x[0]))
            
            # Limit to top 20 countries if requested
            if limit_country_rows:
                top_n = 20
                limited_data = sorted_data[:top_n]
                print(f"[DEBUG] Country Report: Showing top {top_n} countries, actual shown: {len(limited_data)}")
                # Add ranking numbers to limited data
                data_with_ranks = []
                for i, row in enumerate(limited_data, 1):
                    rank_class = "top-5" if i <= 5 else ""
                    rank_html = f'<span class="rank-number {rank_class}">{i}</span>'
                    data_with_ranks.append([rank_html] + row)
                if total_row:
                    # Add total row with reordered columns (no rank)
                    data_with_ranks.append([
                        '',  # No rank for total
                        total_row[country_idx],
                        format_cell_value(total_row[percentage_idx], 'Percentage'),
                        total_row[user_count_idx]
                    ])
                data_to_show = data_with_ranks
            else:
                # Show all countries with ranking numbers
                print(f"[DEBUG] Country Report: Showing all countries, actual shown: {len(sorted_data)}")
                data_with_ranks = []
                for i, row in enumerate(sorted_data, 1):
                    rank_class = "top-5" if i <= 5 else ""
                    rank_html = f'<span class="rank-number {rank_class}">{i}</span>'
                    data_with_ranks.append([rank_html] + row)
                if total_row:
                    data_with_ranks.append([
                        '',  # No rank for total
                        total_row[country_idx],
                        format_cell_value(total_row[percentage_idx], 'Percentage'),
                        total_row[user_count_idx]
                    ])
                data_to_show = data_with_ranks
        elif filename == 'platformReport.csv' or filename == 'Platform Report':
            # Platform report sorting logic - reorder to Platform, Percentage, User Count
            platform_idx = headers.index('Platform')
            user_count_idx = headers.index('User Count')
            percentage_idx = headers.index('% of Users')
            
            total_row = None
            other_data = []
            for row in data:
                if row[platform_idx] == 'Total':
                    total_row = row
                else:
                    other_data.append(row)
            
            # Create new rows with reordered columns and add platform icons
            processed_data = []
            for row in other_data:
                platform_name = row[platform_idx]
                if platform_name.lower() == 'ios':
                    display_name = '🍎 iOS'
                elif platform_name.lower() == 'android':
                    display_name = '🤖 Android'
                else:
                    display_name = platform_name
                processed_data.append([
                    display_name,
                    format_cell_value(row[percentage_idx], 'Percentage'),
                    row[user_count_idx]
                ])
            
            # Sort by percentage (handle empty values)
            def safe_float_sort(x):
                try:
                    return float(x[1].rstrip('%')) if x[1].strip() else 0.0
                except (ValueError, TypeError):
                    return 0.0
            sorted_data = sorted(processed_data, key=safe_float_sort, reverse=True)
            
            if total_row:
                # Add total row with reordered columns
                sorted_data.append([
                    total_row[platform_idx],
                    format_cell_value(total_row[percentage_idx], 'Percentage'),
                    total_row[user_count_idx]
                ])
                
            data_to_show = sorted_data
        elif filename == 'Band Rankings':
            # Add rank numbers to Band Rankings
            data_with_ranks = []
            for i, row in enumerate(data, 1):
                rank_class = "top-5" if i <= 5 else ""
                rank_html = f'<span class="rank-number {rank_class}">{i}</span>'
                data_with_ranks.append([rank_html] + row)
            data_to_show = data_with_ranks
        elif filename == 'bandCountReport.csv':
            # For band count report, prepare data with only selected columns
            # Now, data is already in the form [Band, % Must, Must]
            data_to_show = data
        elif filename == 'eventCountReport.csv':
            # For event count report, data is already in correct format: Event, # Attended, Total Users, % Attended
            # Reorder to: Event, % Attended, # Attended, Total Users and show top 20
            event_idx = headers.index('Event')
            attended_idx = headers.index('# Attended')
            total_users_idx = headers.index('Total Users')
            pct_attended_idx = headers.index('% Attended')
            
            processed_data = []
            for row in data:
                processed_data.append([
                    row[event_idx],
                    row[pct_attended_idx],
                    row[attended_idx],
                    row[total_users_idx]
                ])
            
            # Sort by attendance count descending and take top 20
            data_to_show = sorted(processed_data, key=lambda x: int(x[2]) if x[2] and str(x[2]).strip() else 0, reverse=True)[:20]
        elif filename == 'Event Attendance':
            # For Event Attendance, data is in format: Event, # Attended, Total Users, % Attended, Est. Attendance
            # Reorder to: Event, % Attended, # Attended, Total Users, Est. Attendance and show ALL events
            event_idx = headers.index('Event')
            attended_idx = headers.index('# Attended')
            total_users_idx = headers.index('Total Users')
            pct_attended_idx = headers.index('% Attended')
            est_attendance_idx = headers.index('Est. Attendance')
            
            processed_data = []
            for row in data:
                processed_data.append([
                    row[event_idx],
                    row[pct_attended_idx],
                    row[attended_idx],
                    row[total_users_idx],
                    row[est_attendance_idx]
                ])
            
            # Sort by attendance count descending and show ALL events (not limited)
            data_to_show = sorted(processed_data, key=lambda x: int(x[2]) if x[2] and str(x[2]).strip() else 0, reverse=True)
        elif filename == 'genreReport.csv':
            # For genre report, show all entries
            data_to_show = data
        else:
            data_to_show = data[:20]
            
        for row in data_to_show:
            # Add special class for Total row
            is_total = False
            if len(row) > 0 and row[0] == 'Total':
                is_total = True
            row_class = ' class="total-row"' if is_total else ''
            table_html += f'<tr{row_class}>'
            for i, cell in enumerate(row):
                # Don't escape HTML if it contains rank-number spans
                if '<span class="rank-number' in str(cell):
                    cell_value = str(cell)
                else:
                    cell_value = escape_html(cell)
                if is_total and i == 0:
                    table_html += f'<td data-en="Total">{cell_value}</td>\n'
                else:
                    cell_class = ' class="number-cell"' if str(cell).replace('<span class="rank-number', '').replace('.', '').replace('%', '').replace(',', '').replace('</span>', '').strip().isdigit() else ''
                    table_html += f'<td{cell_class}>{cell_value}</td>\n'
            table_html += '</tr>\n'
        table_html += '</tbody>\n'
        table_html += '</table>\n'
        table_html += '</div>'
        return table_html

    tab_buttons = ""
    tab_contents = ""
    
    for i, file_data in enumerate(csv_files):
        if len(file_data) == 4:
            filename, headers, data, mod_date = file_data
        else:
            filename, headers, data = file_data
            mod_date = None
        print(f"[DEBUG] Processing tab {i}: filename={filename}")
        tab_id = f"tab-{i}"
        # Use canonical translation keys for main tabs
        if filename == 'Band Rankings':
            display_name = 'Band Rankings'
        elif filename == 'Country Report':
            display_name = 'Countries'
        elif filename == 'Platform Report':
            display_name = 'Platforms'
        elif filename == 'OS Version':
            display_name = 'OS Version'
        elif filename == '70K Version':
            display_name = '70K Version'
        else:
            display_name = format_title(filename)
        # Determine original data length for limiting note
        if filename == 'Band Rankings':
            original_data_len = len(data)
        elif filename in ('Country Report', 'Platform Report'):
            # Use the original data length before limiting (from main)
            original_data_len = None
            try:
                if filename == 'Country Report':
                    import builtins
                    original_data_len = builtins.country_rows_original_len if hasattr(builtins, 'country_rows_original_len') else len(data)
                elif filename == 'Platform Report':
                    import builtins
                    original_data_len = builtins.platform_rows_original_len if hasattr(builtins, 'platform_rows_original_len') else len(data)
            except Exception:
                original_data_len = len(data)
        else:
            original_data_len = len(data)
        # Generate tab button with data-en attribute for translation
        tab_buttons += generate_tab_button(tab_id, escape_html(display_name), i == 0, en_name=display_name)
        # Generate tab content
        print(f"[DEBUG] Calling generate_table_html for filename={filename}, limit_country_rows={limit_country_rows}")
        table_html = generate_table_html(headers, data, filename, mod_date, original_data_len, limit_country_rows=limit_country_rows) if data else '<div class="no-data">No data available</div>'
        # Add band rankings percentage note at the bottom of the Band Rankings tab
        if filename == 'Band Rankings':
            # Always prepend the top N note for Band Rankings in the main report (not full)
            import builtins
            band_display_limit = getattr(builtins, 'band_rows_original_len', None)
            if band_display_limit is not None and limit_country_rows:
                table_html = f'<div class="showing-top-note" data-n="{band_display_limit}" style="color: #888; margin-bottom: 10px; font-style: italic;">Showing top {band_display_limit} entries only</div>' + table_html
            table_html += '<div class="band-rankings-note" data-en="The total used for the percentage calculation is based on the number of Must, Might, and Wont votes a band received.">The total used for the percentage calculation is based on the number of Must, Might, and Wont votes a band received.</div>'
        # For Country Report, prepend the top N note to the table HTML (above the table)
        if filename and filename.strip().lower() in ('countryreport.csv', 'country report') and limit_country_rows:
            top_n = 20
            table_html = f'<div class="showing-top-note" data-n="{top_n}" style="color: #888; margin-bottom: 10px; font-style: italic;">Showing top {top_n} entries only</div>' + table_html
        tab_contents += generate_tab_content(tab_id, table_html, i == 0)

    # Load the HTML template from file
    template_path = Path(HTML_TEMPLATE_FILE)
    if not template_path.exists():
        raise FileNotFoundError(f'{HTML_TEMPLATE_FILE} not found!')
    with open(template_path, 'r', encoding='utf-8') as f:
        template_html = f.read()

    # Substitute placeholders
    event_year = (_FESTIVAL_CONTEXT.event_year if _FESTIVAL_CONTEXT else "").strip()
    page_title = dashboard_title("Stats", event_year)
    html_content = template_html.replace('<title>Stats</title>', f'<title>{html.escape(page_title)}</title>')
    html_content = html_content.replace(
        'data-en="Stats">Stats</h1>',
        f'data-en="Stats">{html.escape(page_title)}</h1>',
    )
    html_content = html_content.replace('{{ tab_buttons }}', tab_buttons)
    html_content = html_content.replace('{{ tab_contents }}', tab_contents)
    html_content = html_content.replace('{{ last_generated }}', last_generated)
    return html_content


def generate_language_specific_html(csv_files: List[tuple[str, List[str], List[Dict[str, Any]], str]], last_generated: str, language: str, limit_country_rows: bool = True) -> str:
    """
    Generate HTML content for a specific language with hardcoded translations.
    
    Args:
        csv_files: List of tuples containing filename, headers, data, and modification date
        last_generated: Timestamp string for when the report was generated
        language: Language code (en, da, de, es, fi, fr, pt)
        limit_country_rows: Whether to limit the number of country rows shown
    
    Returns:
        The generated HTML content as a string with hardcoded translations
    """
    if language not in TRANSLATIONS:
        raise ValueError(f"Unsupported language: {language}")
    
    translations = TRANSLATIONS[language]
    
    def generate_tab_button(tab_id, tab_name, is_first=False, en_name=None):
        active_class = ' active' if is_first else ''
        
        # Add icons to tab names
        icon_map = {
            'Band Rankings': '🎵',
            'Countries': '🌍', 
            'Platforms': '📱',
            'Band Country': '🏁',
            'Band Repeats': '🔄',
            'Top Band by Country': '🏆',
            'Platform by Country': '🌐',
            'Event Attendance': '🎫',
            'Daily Usage': '📊',
            'Monthly Usage': '📅',
            'OS Version': '⚙️',
            '70K Version': '📲'
        }
        
        # Use en_name for icon lookup if available, otherwise use tab_name
        # For language-specific versions, we need to map translated names back to English
        reverse_lookup = {
            'Top Bands': 'Band Rankings', 'Band-Rangliste': 'Band Rankings', 'Ranking de bandas': 'Band Rankings',
            'Bändien sijoitukset': 'Band Rankings', 'Classement des groupes': 'Band Rankings',
            'Lande': 'Countries', 'Länder': 'Countries', 'Países': 'Countries', 'Maat': 'Countries', 'Pays': 'Countries',
            'Platforme': 'Platforms', 'Plattformen': 'Platforms', 'Plataformas': 'Platforms', 'Alustat': 'Platforms', 'Plateformes': 'Platforms'
        }
        lookup_name = en_name or reverse_lookup.get(tab_name, tab_name)
        icon = icon_map.get(lookup_name, '')
        display_name = f"{icon} {tab_name}" if icon else tab_name
        
        return f'<button class="tab-button{active_class}" onclick="openTab(event, \'{tab_id}\')">{display_name}</button>'

    def generate_tab_content(tab_id, content, is_first=False):
        display_style = 'block' if is_first else 'none'
        return f'<div id="{tab_id}" class="tab-content" style="display: {display_style}">{content}</div>'

    def generate_table_html(headers, data, filename=None, mod_date=None, original_data_len=None, limit_country_rows: bool = True):
        table_html = '<div style="overflow-x: auto;">\n'
        # Add file modification date if available
        if mod_date:
            # Handle both tuple (formatted_string, epoch) and plain string formats
            if isinstance(mod_date, tuple) and len(mod_date) == 2:
                formatted_date, epoch = mod_date
                table_html += f'<div style="color: #888; margin-bottom: 10px; font-size: 12px; font-style: italic;">{translations.get("Last updated:", "Last updated:")} <span data-timestamp="{epoch}">{formatted_date}</span></div>\n'
            else:
                # Backward compatibility: plain string
                table_html += f'<div style="color: #888; margin-bottom: 10px; font-size: 12px; font-style: italic;">{translations.get("Last updated:", "Last updated:")} {mod_date}</div>\n'
        
        # Add note about data limitation if applicable
        if original_data_len is not None:
            # For Country/Platform, exclude total row from count
            if filename and filename.strip().lower() in ('countryreport.csv', 'country report'):
                shown = len(data) - 1 if len(data) > 0 else 0
                orig = original_data_len - 1 if original_data_len > 0 else 0
            else:
                shown = len(data)
                orig = original_data_len
            if shown < orig:
                showing_top = translations.get('Showing top', 'Showing top')
                entries_only = translations.get('entries only', 'entries only')
                table_html += f'<div class="showing-top-note" style="color: #888; margin-bottom: 10px; font-style: italic;">{showing_top} {shown} {entries_only}</div>\n'
        # Always add country count note for Country Report (both standard and full reports)
        if filename and filename.strip().lower() in ('countryreport.csv', 'country report'):
            num_countries = getattr(builtins, 'country_count_unique', None)
            if num_countries is not None:
                country_note_template = translations.get('The app is being used by users in {{n}} countries.', 'The app is being used by users in {{n}} countries.')
                note_text = country_note_template.replace('{{n}}', str(num_countries))
                table_html += f'<div class="country-count-note" style="color: #888; margin-bottom: 10px; font-style: italic;">{note_text}</div>\n'
        
        table_html += '<table class="data-table">\n'
        
        # Generate headers
        table_html += '<thead>\n<tr>\n'
        
        # Handle different reports
        if filename and filename.strip().lower() in ('countryreport.csv', 'country report'):
            # For country report, show Rank, Country, Percentage, User Count
            country_headers = [
                'Rank',
                translations.get('Country', 'Country'),
                translations.get('% Of Users', '% Of Users'),
                translations.get('User Count', 'User Count')
            ]
            for header in country_headers:
                title_attr = f' title="{translations.get("Tap/click truncated names to see full text", "Tap/click truncated names to see full text")}"' if header == translations.get('Country', 'Country') else ''
                table_html += f'<th{title_attr}>{escape_html(header)}</th>\n'
        elif filename == 'bandCountReport.csv':
            # For band count report, only include Rank, Band, % Must, and Must columns
            selected_headers = [
                'Rank',
                translations.get('Band Name', 'Band Name'),
                translations.get('% Must', '% Must'),
                translations.get('Must', 'Must')
            ]
            for header in selected_headers:
                table_html += f'<th>{escape_html(header)}</th>\n'
        elif filename == 'eventCountReport.csv':
            # For event count report, show Event, % Attended, # Attended, Total Users
            new_headers = [
                translations.get('Event', 'Event'),
                translations.get('% Attended', '% Attended'),
                translations.get('# Attended', '# Attended'),
                translations.get('Total Users', 'Total Users')
            ]
            for header in new_headers:
                title_attr = f' title="{translations.get("Tap/click truncated names to see full text", "Tap/click truncated names to see full text")}"' if header == translations.get('Event', 'Event') else ''
                table_html += f'<th{title_attr}>{escape_html(header)}</th>\n'
        elif filename == 'platformReport.csv' or filename == 'Platform Report':
            # For platform report, show Platform, % of Users, User Count
            platform_headers = [
                translations.get('Platform', 'Platform'),
                translations.get('% Of Users', '% Of Users'),
                translations.get('User Count', 'User Count')
            ]
            for header in platform_headers:
                table_html += f'<th>{escape_html(header)}</th>\n'
        else:
            for header in headers:
                table_html += f'<th>{escape_html(header)}</th>\n'
        table_html += '</tr>\n</thead>\n'
        
        # Generate body
        table_html += '<tbody>\n'
        
        # Handle sorting and data preparation
        if filename and filename.strip().lower() in ('countryreport.csv', 'country report'):
            # Country report sorting logic - reorder to Country, Percentage, User Count
            
            total_row = None
            other_data = []
            for row in data:
                if row[0] == translations.get('Total', 'Total'):
                    total_row = row
                else:
                    other_data.append(row)
            
            # Create new rows with reordered columns and add country flags
            country_flags = {
                'United States': '🇺🇸', 'Canada': '🇨🇦', 'Germany': '🇩🇪', 'Switzerland': '🇨🇭',
                'Finland': '🇫🇮', 'Netherlands': '🇳🇱', 'France': '🇫🇷', 'Mexico': '🇲🇽',
                'Belgium': '🇧🇪', 'Colombia': '🇨🇴', 'Austria': '🇦🇹', 'Costa Rica': '🇨🇷',
                'Norway': '🇳🇴', 'Australia': '🇦🇺', 'Hungary': '🇭🇺', 'Puerto Rico': '🇵🇷',
                'Brazil': '🇧🇷', 'Greece': '🇬🇷', 'Czech Republic': '🇨🇿', 'Tunisia': '🇹🇳',
                'Sweden': '🇸🇪', 'Italy': '🇮🇹', 'United Kingdom': '🇬🇧', 'Denmark': '🇩🇰',
                'Andorra': '🇦🇩', 'Faroe Islands': '🇫🇴', 'Poland': '🇵🇱', 'Chile': '🇨🇱',
                'Ukraine': '🇺🇦', 'Japan': '🇯🇵', 'Portugal': '🇵🇹', 'International': '🌍'
            }
            processed_data = []
            for row in other_data:
                country_name = row[0]
                flag = country_flags.get(country_name, '')
                display_name = f"{flag} {country_name}" if flag else country_name
                processed_data.append([
                    display_name,
                    format_cell_value(row[1], 'Percentage'),
                    row[2]
                ])
            # Sort by user count descending, then by country name
            sorted_data = sorted(processed_data, key=lambda x: (-int(x[2]), x[0]))
            
            # Limit to top 20 countries if requested and add ranking numbers
            if limit_country_rows:
                top_n = 20
                limited_data = sorted_data[:top_n]
                # Add ranking numbers to limited data
                data_with_ranks = []
                for i, row in enumerate(limited_data, 1):
                    rank_class = "top-5" if i <= 5 else ""
                    rank_html = f'<span class="rank-number {rank_class}">{i}</span>'
                    data_with_ranks.append([rank_html] + row)
                if total_row:
                    # Add total row with reordered columns (no rank)
                    data_with_ranks.append([
                        '',  # No rank for total
                        total_row[0],
                        format_cell_value(total_row[1], 'Percentage'),
                        total_row[2]
                    ])
                data_to_show = data_with_ranks
            else:
                # Show all countries with ranking numbers
                data_with_ranks = []
                for i, row in enumerate(sorted_data, 1):
                    rank_class = "top-5" if i <= 5 else ""
                    rank_html = f'<span class="rank-number {rank_class}">{i}</span>'
                    data_with_ranks.append([rank_html] + row)
                if total_row:
                    data_with_ranks.append([
                        '',  # No rank for total
                        total_row[0],
                        format_cell_value(total_row[1], 'Percentage'),
                        total_row[2]
                    ])
                data_to_show = data_with_ranks
        elif filename == 'platformReport.csv' or filename == 'Platform Report':
            # Platform report sorting logic - reorder to Platform, Percentage, User Count
            platform_idx = headers.index('Platform')
            user_count_idx = headers.index('User Count')
            percentage_idx = headers.index('% of Users')
            
            total_row = None
            other_data = []
            for row in data:
                if row[platform_idx] == translations.get('Total', 'Total'):
                    total_row = row
                else:
                    other_data.append(row)
            
            # Create new rows with reordered columns
            processed_data = []
            for row in other_data:
                platform_name = row[platform_idx]
                if platform_name.lower() == 'ios':
                    display_name = '🍎 iOS'
                elif platform_name.lower() == 'android':
                    display_name = '🤖 Android'
                else:
                    display_name = platform_name
                processed_data.append([
                    display_name,
                    format_cell_value(row[percentage_idx], 'Percentage'),
                    row[user_count_idx]
                ])
            
            # Sort by percentage (handle empty values)
            def safe_float_sort(x):
                try:
                    return float(x[1].rstrip('%')) if x[1].strip() else 0.0
                except (ValueError, TypeError):
                    return 0.0
            sorted_data = sorted(processed_data, key=safe_float_sort, reverse=True)
            
            if total_row:
                # Add total row with reordered columns
                sorted_data.append([
                    total_row[platform_idx],
                    format_cell_value(total_row[percentage_idx], 'Percentage'),
                    total_row[user_count_idx]
                ])
                
            data_to_show = sorted_data
        elif filename == 'Band Rankings':
            # Add rank numbers to Band Rankings
            data_with_ranks = []
            for i, row in enumerate(data, 1):
                rank_class = "top-5" if i <= 5 else ""
                rank_html = f'<span class="rank-number {rank_class}">{i}</span>'
                data_with_ranks.append([rank_html] + row)
            data_to_show = data_with_ranks
        elif filename == 'bandCountReport.csv':
            # For band count report, prepare data with only selected columns
            # Now, data is already in the form [Band, % Must, Must]
            data_to_show = data
        elif filename == 'eventCountReport.csv':
            # For event count report, data is already in correct format: Event, # Attended, Total Users, % Attended
            # Reorder to: Event, % Attended, # Attended, Total Users and show top 20
            event_idx = headers.index('Event')
            attended_idx = headers.index('# Attended')
            total_users_idx = headers.index('Total Users')
            pct_attended_idx = headers.index('% Attended')
            
            processed_data = []
            for row in data:
                processed_data.append([
                    row[event_idx],
                    row[pct_attended_idx],
                    row[attended_idx],
                    row[total_users_idx]
                ])
            
            # Sort by attendance count descending and take top 20
            data_to_show = sorted(processed_data, key=lambda x: int(x[2]) if x[2] and str(x[2]).strip() else 0, reverse=True)[:20]
        elif filename == 'Event Attendance':
            # For Event Attendance, data is in format: Event, # Attended, Total Users, % Attended, Est. Attendance
            # Reorder to: Event, % Attended, # Attended, Total Users, Est. Attendance and show ALL events
            event_idx = headers.index('Event')
            attended_idx = headers.index('# Attended')
            total_users_idx = headers.index('Total Users')
            pct_attended_idx = headers.index('% Attended')
            est_attendance_idx = headers.index('Est. Attendance')
            
            processed_data = []
            for row in data:
                processed_data.append([
                    row[event_idx],
                    row[pct_attended_idx],
                    row[attended_idx],
                    row[total_users_idx],
                    row[est_attendance_idx]
                ])
            
            # Sort by attendance count descending and show ALL events (not limited)
            data_to_show = sorted(processed_data, key=lambda x: int(x[2]) if x[2] and str(x[2]).strip() else 0, reverse=True)
        elif filename == 'genreReport.csv':
            # For genre report, show all entries
            data_to_show = data
        else:
            data_to_show = data[:20]
            
        for row in data_to_show:
            # Add special class for Total row
            is_total = False
            if len(row) > 0 and row[0] == translations.get('Total', 'Total'):
                is_total = True
            row_class = ' class="total-row"' if is_total else ''
            table_html += f'<tr{row_class}>'
            for i, cell in enumerate(row):
                # Don't escape HTML if it contains rank-number spans
                if '<span class="rank-number' in str(cell):
                    cell_value = str(cell)
                else:
                    cell_value = escape_html(cell)
                if is_total and i == 0:
                    table_html += f'<td>{cell_value}</td>\n'
                else:
                    cell_class = ' class="number-cell"' if str(cell).replace('<span class="rank-number', '').replace('.', '').replace('%', '').replace(',', '').replace('</span>', '').strip().isdigit() else ''
                    table_html += f'<td{cell_class}>{cell_value}</td>\n'
            table_html += '</tr>\n'
        table_html += '</tbody>\n'
        table_html += '</table>\n'
        table_html += '</div>'
        return table_html

    tab_buttons = ""
    tab_contents = ""
    
    for i, file_data in enumerate(csv_files):
        if len(file_data) == 4:
            filename, headers, data, mod_date = file_data
        else:
            filename, headers, data = file_data
            mod_date = None
        
        tab_id = f"tab-{i}"
        # Use canonical translation keys for main tabs
        if filename == 'Band Rankings':
            display_name = translations.get('Band Rankings', 'Band Rankings')
        elif filename == 'Country Report':
            display_name = translations.get('Countries', 'Countries')
        elif filename == 'Platform Report':
            display_name = translations.get('Platforms', 'Platforms')
        elif filename == 'OS Version':
            display_name = translations.get('OS Version', 'OS Version')
        elif filename == '70K Version':
            display_name = translations.get('70K Version', '70K Version')
        else:
            display_name = format_title(filename)
        
        # Determine original data length for limiting note
        if filename == 'Band Rankings':
            original_data_len = len(data)
        elif filename in ('Country Report', 'Platform Report'):
            # Use the original data length before limiting (from main)
            original_data_len = None
            try:
                if filename == 'Country Report':
                    import builtins
                    original_data_len = builtins.country_rows_original_len if hasattr(builtins, 'country_rows_original_len') else len(data)
                elif filename == 'Platform Report':
                    import builtins
                    original_data_len = builtins.platform_rows_original_len if hasattr(builtins, 'platform_rows_original_len') else len(data)
            except Exception:
                original_data_len = len(data)
        else:
            original_data_len = len(data)
        
        # Generate tab button
        tab_buttons += generate_tab_button(tab_id, escape_html(display_name), i == 0)
        
        # Generate tab content
        table_html = generate_table_html(headers, data, filename, mod_date, original_data_len, limit_country_rows=limit_country_rows) if data else f'<div class="no-data">{translations.get("No data available", "No data available")}</div>'
        
        # Add band rankings percentage note at the bottom of the Band Rankings tab
        if filename == 'Band Rankings':
            # Always prepend the top N note for Band Rankings in the main report (not full)
            import builtins
            band_display_limit = getattr(builtins, 'band_rows_original_len', None)
            if band_display_limit is not None and limit_country_rows:
                showing_top = translations.get('Showing top', 'Showing top')
                entries_only = translations.get('entries only', 'entries only')
                table_html = f'<div class="showing-top-note" style="color: #888; margin-bottom: 10px; font-style: italic;">{showing_top} {band_display_limit} {entries_only}</div>' + table_html
            
            band_rankings_note = translations.get('The total used for the percentage calculation is based on the number of Must, Might, and Wont votes a band received.', 'The total used for the percentage calculation is based on the number of Must, Might, and Wont votes a band received.')
            table_html += f'<div class="band-rankings-note">{band_rankings_note}</div>'
        
        # For Country Report, prepend the top N note to the table HTML (above the table)
        if filename and filename.strip().lower() in ('countryreport.csv', 'country report') and limit_country_rows:
            top_n = 20
            showing_top = translations.get('Showing top', 'Showing top')
            entries_only = translations.get('entries only', 'entries only')
            table_html = f'<div class="showing-top-note" style="color: #888; margin-bottom: 10px; font-style: italic;">{showing_top} {top_n} {entries_only}</div>' + table_html
        
        tab_contents += generate_tab_content(tab_id, table_html, i == 0)

    # Create a simplified HTML template for language-specific versions
    html_template = f"""<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{html.escape(dashboard_title(translations.get('Stats', 'Stats'), (_FESTIVAL_CONTEXT.event_year if _FESTIVAL_CONTEXT else '')))}</title>
    <style>
        body {{
            background-color: #121212;
            color: white;
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 20px;
            width: 100%;
            max-width: 100vw;
            box-sizing: border-box;
            overflow-x: hidden;
        }}
        .dashboard-title {{
            color: #50fa7b;
            text-align: center;
            margin-bottom: 30px;
            font-size: 24px;
            word-wrap: break-word;
        }}
        .tab-container {{
            background: #1e1e1e;
            border-radius: 8px;
            overflow: hidden;
            box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
            width: 100%;
            max-width: 100%;
        }}
        .tab-buttons {{
            display: flex;
            flex-wrap: wrap;
            background: #1e1e1e;
            border-bottom: 2px solid #50fa7b;
            width: 100%;
        }}
        .tab-button {{
            background: none;
            border: none;
            padding: 15px 20px;
            color: #888;
            cursor: pointer;
            transition: all 0.3s ease;
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
            flex: 1 1 auto;
            min-width: fit-content;
            font-size: 16px;
        }}
        .tab-button:hover {{
            background: #2a2a2a;
            color: white;
        }}
        .tab-button.active {{
            background: #2a2a2a;
            color: #50fa7b;
            border-bottom: 2px solid #50fa7b;
            margin-bottom: -2px;
        }}
        .tab-content {{
            display: none;
            padding: 20px;
            overflow-x: auto;
            -webkit-overflow-scrolling: touch;
            max-width: 100%;
        }}
        .tab-content.active {{
            display: block;
        }}
        .data-table {{
            width: 100%;
            border-collapse: collapse;
            margin-top: 10px;
            background: #1e1e1e;
            table-layout: auto;
        }}
        .data-table th,
        .data-table td {{
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #333;
            white-space: nowrap;
        }}
        .data-table th {{
            background: #2a2a2a;
            color: #50fa7b;
            font-weight: bold;
            position: sticky;
            top: 0;
            z-index: 1;
        }}
        .data-table tr:hover {{
            background: #2a2a2a;
        }}
        .number-cell {{
            text-align: right;
        }}
        .total-row {{
            background: #2a2a2a;
            border-top: 2px solid #50fa7b;
            font-weight: bold;
        }}
        .total-row:hover {{
            background: #333 !important;
        }}
        .truncated-text {{
            cursor: pointer;
            position: relative;
            max-width: 200px;
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
        }}
        .rank-number {{
            display: inline-flex;
            align-items: center;
            justify-content: center;
            width: 20px;
            height: 20px;
            border-radius: 50%;
            background: #333;
            color: #888;
            font-size: 10px;
            font-weight: 600;
            margin-right: 8px;
            font-variant-numeric: tabular-nums;
        }}
        .rank-number.top-5 {{
            background: #50fa7b;
            color: #121212;
            font-weight: bold;
        }}
        .platform-icon {{
            margin-right: 6px;
            font-size: 16px;
        }}
        .truncated-text.show-tooltip::after,
        .truncated-text:hover::after {{
            content: attr(title);
            position: fixed;
            left: 50%;
            top: 50%;
            transform: translate(-50%, -50%);
            background: #2a2a2a;
            color: white;
            padding: 10px 15px;
            border-radius: 4px;
            border: 1px solid #50fa7b;
            z-index: 1000;
            white-space: normal;
            max-width: 80vw;
            width: auto;
            text-align: center;
            box-shadow: 0 4px 8px rgba(0,0,0,0.2);
            word-break: break-word;
            font-size: 14px;
        }}
        .data-note {{
            color: #888;
            font-size: 12px;
            font-style: italic;
            margin-bottom: 10px;
            text-align: center;
        }}
        .band-rankings-note {{
            color: #888;
            font-size: 12px;
            font-style: italic;
            margin-top: 20px;
            text-align: center;
        }}
        .note {{
            color: #888;
            margin-bottom: 10px;
            font-style: italic;
            font-size: 12px;
            display: block;
        }}
        .country-count-note {{
            text-align: left;
            display: block;
        }}
        .showing-top-note {{
            text-align: left;
            display: block;
        }}
        @media (max-width: 768px) {{
            body {{
                padding: 10px;
            }}
            .dashboard-title {{
                font-size: 20px;
            }}
            .tab-button {{
                padding: 10px;
                font-size: 15px;
                text-align: center;
            }}
            .data-table th,
            .data-table td {{
                padding: 8px;
                font-size: 14px;
            }}
            .truncated-text {{
                max-width: 150px;
            }}
            .truncated-text.show-tooltip::after,
            .truncated-text:hover::after {{
                padding: 15px;
                font-size: 16px;
                min-width: 200px;
            }}
        }}
        @media (max-width: 480px) {{
            .dashboard-title {{
                font-size: 18px;
            }}
            .tab-button {{
                padding: 8px;
                font-size: 13px;
            }}
            .data-table th,
            .data-table td {{
                padding: 6px;
                font-size: 12px;
            }}
            .truncated-text {{
                max-width: 120px;
            }}
        }}
    </style>
    <script>
    function openTab(evt, tabName) {{
        var i, tabcontent, tablinks;
        tabcontent = document.getElementsByClassName("tab-content");
        for (i = 0; i < tabcontent.length; i++) {{
            tabcontent[i].style.display = "none";
        }}
        tablinks = document.getElementsByClassName("tab-button");
        for (i = 0; i < tablinks.length; i++) {{
            tablinks[i].className = tablinks[i].className.replace(" active", "");
        }}
        document.getElementById(tabName).style.display = "block";
        evt.currentTarget.className += " active";
    }}
    // Handle truncated text interactions
    function handleTruncatedText(element) {{
        // Remove show-tooltip class from all other elements
        document.querySelectorAll('.truncated-text').forEach(el => {{
            if (el !== element) {{
                el.classList.remove('show-tooltip');
            }}
        }});
        // Toggle show-tooltip class on clicked element
        element.classList.toggle('show-tooltip');
        // Add click event to body to close tooltip when clicking outside
        document.body.addEventListener('click', function closeTooltip(e) {{
            if (!element.contains(e.target)) {{
                element.classList.remove('show-tooltip');
                document.body.removeEventListener('click', closeTooltip);
            }}
        }});
    }}
    // Convert epoch timestamps to user's local timezone
    function convertTimestamps() {{
        document.querySelectorAll('[data-timestamp]').forEach(function(element) {{
            const epoch = parseInt(element.dataset.timestamp);
            if (!isNaN(epoch) && epoch > 0) {{
                const date = new Date(epoch * 1000);
                // Get timezone name
                const timezoneName = new Intl.DateTimeFormat('en-US', {{timeZoneName: 'short'}}).formatToParts(date).find(part => part.type === 'timeZoneName')?.value || 'UTC';
                // Format: January 25, 2026 at 12:00 PM PST
                const options = {{
                    year: 'numeric',
                    month: 'long',
                    day: 'numeric',
                    hour: 'numeric',
                    minute: '2-digit',
                    hour12: true
                }};
                const formatted = new Intl.DateTimeFormat('en-US', options).format(date);
                element.textContent = formatted + ' ' + timezoneName;
            }}
        }});
    }}
    // Open first tab by default and set up event handlers
    document.addEventListener('DOMContentLoaded', function() {{
        // Convert timestamps first
        convertTimestamps();
        // Open first tab
        document.querySelector('.tab-button').click();
        // Add click/touch handlers for truncated text
        document.querySelectorAll('.truncated-text').forEach(function(element) {{
            element.addEventListener('click', function(e) {{
                e.stopPropagation();
                handleTruncatedText(this);
            }});
        }});
    }});
    </script>
</head>
<body>
    <h1 class="dashboard-title">{html.escape(dashboard_title(translations.get('Stats', 'Stats'), (_FESTIVAL_CONTEXT.event_year if _FESTIVAL_CONTEXT else '')))}</h1>
    <div class="tab-container">
        <div class="tab-buttons">
            {tab_buttons}
        </div>
        {tab_contents}
    </div>
    <div id="data-note" class="data-note">{translations.get('All data based on users who have used the app in the last 30 days.', 'All data based on users who have used the app in the last 30 days.')}</div>
    <div id="report-generated" style="color: #888; margin-bottom: 10px; font-size: 12px; font-style: italic; text-align: center;"><span id="report-generated-label">{translations.get('Report generated:', 'Report generated:')}</span> {last_generated}</div>
</body>
</html>"""

    return html_template


def generate_all_language_files(processed_files: List[tuple[str, List[str], List[Dict[str, Any]], str]], last_generated: str, source: str = '70K_Bands') -> None:
    """
    Generate language-specific versions of the dashboard.
    
    Args:
        processed_files: List of tuples containing filename, headers, data, and modification date
        last_generated: Timestamp string for when the report was generated
        source: Data source ('70K_Bands' or 'MDF_Bands')
    """
    print("\nGenerating language-specific versions...")
    
    # Get source-specific language files
    file_paths = get_file_paths(source)
    language_files = file_paths['language_files']
    
    for language, output_file in language_files.items():
        try:
            # Generate language-specific HTML content
            html_content = generate_language_specific_html(processed_files, last_generated, language, limit_country_rows=True)
            
            # Write HTML file
            output_path = Path('.') / output_file
            with open(output_path, 'w', encoding='utf-8') as f:
                f.write(html_content)
            print(f"✓ {language.upper()} HTML report generated successfully: {output_path}")
        except Exception as e:
            print(f"✗ Error writing {language.upper()} HTML file: {e}")


def process_genre_data(file_path: Path) -> tuple[List[str], List[List[str]]]:
    """
    Process genre data from the artist lineup file.
    
    Args:
        file_path: Path to the artist lineup CSV file
    
    Returns:
        Tuple of (headers, data_rows)
    """
    # Temporarily disabled
    return [], []
    """
    genres = []
    try:
        with open(file_path, 'r', encoding='utf-8') as file:
            csv_reader = csv.DictReader(file)
            for row in csv_reader:
                if row['genre']:  # Skip empty genre entries
                    genres.append(row['genre'].strip())
    
        # Count genres
        genre_counts = Counter(genres)
        total_count = sum(genre_counts.values())
        
        # Convert to percentage and create sorted data
        data = []
        for genre, count in sorted(genre_counts.items(), key=lambda x: (-x[1], x[0])):
            percentage = (count / total_count) * 100
            data.append([
                genre,
                str(count),
                f"{percentage:.1f}%"
            ])
            
        headers = ['Genre', 'Count', 'Percentage']
        return headers, data
        
    except Exception as e:
        print(f"Error processing genre data from {file_path}: {e}")
        return [], []
    """


def main(output_file: str = None, source: str = '70K_Bands', min_votes: int = 50) -> None:
    """
    Main function to process CSV files and generate HTML.
    
    Args:
        output_file: The output HTML file name
        source: Data source ('70K_Bands' or 'MDF_Bands')
        min_votes: Minimum Must votes required for a band to appear (exclusive; default: 50)
    """
    file_paths = get_file_paths(source)
    static_files = file_paths['static_files']
    event_year = file_paths.get('event_year', '')
    
    # Set output file if not provided
    if output_file is None:
        output_file = file_paths['output_main']
    
    print(f"Processing {source} data...")
    print(f"Production pointer: {file_paths.get('pointer_path', '')}")
    print(f"Event year: {event_year}")
    print(f"Artist lineup: {file_paths.get('artist_lineup', '')}")
    print(f"Output file: {output_file}")

    # --- Platform Report ---
    platform_data = []
    user_count = 0
    platform_counts = {}
    user_file = Path(static_files['userData'])
    # --- Prepare date filtering ---
    now = datetime.now()
    cutoff = now - timedelta(days=30)
    filtered_users = []
    total_users = 0
    excluded_users = 0
    if user_file.exists():
        with open_csv_robust(user_file) as f:
            reader = csv.DictReader(f)
            # Check if file has headers
            if reader.fieldnames is None:
                print(f"Warning: {user_file} appears to be empty or has no headers")
                return
            # Normalize fieldnames by stripping spaces
            reader.fieldnames = [fn.strip() for fn in reader.fieldnames]
            print('[DEBUG] Normalized CSV fieldnames:', reader.fieldnames)
            print('[DEBUG] First 10 last launch values:')
            for i, row in enumerate(reader):
                # Normalize row keys as well
                row = {k.strip(): v for k, v in row.items()}
                total_users += 1
                if i < 10:
                    print(f"  Row {i+1}: {row.get('last launch', '')}")
                last_launch_str = row.get('last launch', '').strip()
                try:
                    last_launch_dt = datetime.strptime(last_launch_str, '%Y-%m-%d %H:%M:%S')
                except Exception:
                    excluded_users += 1
                    continue  # skip rows with invalid or missing date
                if last_launch_dt < cutoff:
                    excluded_users += 1
                    continue  # skip users not active in last 30 days
                filtered_users.append(row)
    print(f"[DEBUG] Total users in userData.csv: {total_users}")
    print(f"[DEBUG] Users passing last launch filter: {len(filtered_users)}")
    print(f"[DEBUG] Users excluded by filter: {excluded_users}")
    # Deduplicate filtered_users by userID (keep first occurrence)
    unique_users = {}
    for user in filtered_users:
        user_id = user.get('userid')
        if user_id and user_id not in unique_users:
            unique_users[user_id] = user
    filtered_users = list(unique_users.values())
    print(f"[DEBUG] Users after deduplication by userID: {len(filtered_users)}")
    # Now build platform and country counts from filtered_users
    for row in filtered_users:
        platform = row.get('platform', '').strip()
        if platform:
            platform_counts[platform] = platform_counts.get(platform, 0) + 1
        # user_count will be total filtered users
    user_count = len(filtered_users)
    platform_rows = []
    for plat, count in sorted(platform_counts.items(), key=lambda x: -x[1]):
        pct = (count / user_count * 100) if user_count else 0
        platform_rows.append([plat, f"{pct:.1f}%", str(count)])
    platform_rows.append(["Total", "", str(user_count)])
    platform_headers = ["Platform", "% of Users", "User Count"]

    # --- Country Report ---
    country_counts = {}
    for row in filtered_users:
        country = row.get('country', '').strip()
        if country:
            country_counts[country] = country_counts.get(country, 0) + 1
    # Store the number of unique countries for use in the HTML note
    import builtins
    builtins.country_count_unique = len(country_counts)
    user_count_country = len(filtered_users)
    country_rows = []
    for country, count in sorted(country_counts.items(), key=lambda x: -x[1]):
        pct = (count / user_count_country * 100) if user_count_country else 0
        country_rows.append([country, f"{pct:.1f}%", str(count)])
    # Do NOT append the Total row anymore
    country_headers = ["Country", "% of Users", "User Count"]

    # --- Event Report Placeholder ---
    event_headers = ["Coming Soon"]
    event_rows = [["Event report will be available soon."]]

    # --- Band Ranking Report ---
    # Step 1: Load valid bands from artist lineup
    valid_bands = load_valid_bands_from_lineup(source)
    
    # Debug: Test if "Fri - Roof-Top Party" would be filtered out
    test_band = "Fri - Roof-Top Party"
    if is_valid_band(test_band, valid_bands):
        print(f"[DEBUG] WARNING: '{test_band}' is considered valid!")
    else:
        print(f"[DEBUG] '{test_band}' correctly filtered out")
    
    # Step 2: Build set of active user IDs
    active_user_ids = set()
    for user in filtered_users:
        user_id = user.get('userid')
        if user_id:
            active_user_ids.add(user_id)

    # Step 3: Process rankings for bands, only for active users and valid bands
    band_vote_counts = {}  # band -> {'must': int, 'might': int, 'wont': int}
    band_user_seen = {}    # band -> set of userIDs already counted
    darktq_must_userids = []
    unique_band_names = set()  # Track all unique bands regardless of votes
    filtered_out_bands = 0  # Track how many bands were filtered out
    ranking_file = Path(static_files['rankingData'])
    if ranking_file.exists():
        with open(ranking_file, 'r', encoding='utf-8', errors='replace') as f:
            reader = csv.DictReader(f)
            for row in reader:
                user_id = row.get('userID')
                user_id = extract_ranking_user_id(user_id, event_year)
                band = row.get('bandName', '').strip()
                if band:
                    unique_band_names.add(band)
                if not user_id or user_id not in active_user_ids:
                    continue  # skip if not an active user
                ranking = row.get('ranking', '').strip().lower()
                if not band or ranking not in {'must', 'might', 'wont'}:
                    continue
                
                # Filter out bands not in the artist lineup
                if band.lower() not in valid_bands:
                    filtered_out_bands += 1
                    continue
                
                if band not in band_vote_counts:
                    band_vote_counts[band] = {'must': 0, 'might': 0, 'wont': 0}
                    band_user_seen[band] = set()
                # Only count the first occurrence of a userID for a band
                if user_id not in band_user_seen[band]:
                    band_vote_counts[band][ranking] += 1
                    band_user_seen[band].add(user_id)
                # Collect userIDs for first 10 'Must' votes for 'Dark Tranquillity'
                if band.lower() == 'dark tranquillity' and ranking == 'must' and len(darktq_must_userids) < 10:
                    if user_id not in darktq_must_userids:
                        darktq_must_userids.append(user_id)
    
    print(f"[DEBUG] Filtered out {filtered_out_bands} band votes for bands not in artist lineup")
    
    # Debug: Check if "Fri - Roof-Top Party" is in the data
    if any('fri - roof-top party' in band.lower() for band in band_vote_counts.keys()):
        print("[DEBUG] WARNING: 'Fri - Roof-Top Party' found in band_vote_counts!")
        for band in band_vote_counts.keys():
            if 'fri - roof-top party' in band.lower():
                print(f"[DEBUG] Found problematic entry: '{band}' with votes: {band_vote_counts[band]}")
    
    # Print the user records for the first 10 'Must' votes for 'Dark Tranquillity'
    if darktq_must_userids:
        print('\n[DEBUG] First 10 user records for "Must" votes for Dark Tranquillity:')
        for i, uid in enumerate(darktq_must_userids):
            user_record = next((u for u in filtered_users if u.get('userid') == uid), None)
            print(f"  {i+1}. userID={uid}: {user_record}")
    band_rows = []
    for band, votes in band_vote_counts.items():
        must_count = votes['must']
        total_votes = votes['must'] + votes['might'] + votes['wont']
        pct = (must_count / total_votes * 100) if total_votes else 0
        band_rows.append([band, f"{pct:.1f}%", str(must_count)])
    # 1) Keep only bands above the Must vote threshold
    band_rows = [row for row in band_rows if int(row[2]) > min_votes]
    # 2) Rank by % Must descending, then band name
    band_rows = sorted(band_rows, key=lambda x: (-float(x[1].rstrip('%')), x[0]))
    # 3) Trim to cap from announced lineup size (e.g. 36 announced → 15 max)
    announced_band_count = len(valid_bands)
    band_display_limit = band_display_cap(announced_band_count)
    band_rows_display = band_rows[:band_display_limit]
    print(
        f"[DEBUG] Announced bands: {announced_band_count}, "
        f"display cap: {band_display_limit}, "
        f"bands with >{min_votes} Must votes: {len(band_rows)}, "
        f"shown in report: {len(band_rows_display)}"
    )
    band_headers = ["Rank", "Band Name", "% Must", "Must"]
    # Debug: print must, might, wont totals for top 5 bands
    print("\n[DEBUG] Must, Might, Wont totals for top 5 bands:")
    # Get the band names for the top 5 rows
    top5_band_names = [row[0] for row in band_rows_display[:5]]
    for band in top5_band_names:
        votes = band_vote_counts.get(band, {'must': 0, 'might': 0, 'wont': 0})
        print(f"  {band}: must={votes['must']}, might={votes['might']}, wont={votes['wont']}")

    # Store display count for the "showing top N" note in generated HTML
    import builtins
    builtins.band_rows_original_len = len(band_rows_display)

    # --- Band Country Report ---
    # Process artist lineup data for country breakdown
    artist_lineup_file = Path(file_paths['artist_lineup'])
    band_country_rows = []
    band_country_headers = ["Country", "Band Count", "Percentage"]
    
    if artist_lineup_file.exists():
        country_band_counts = {}
        total_bands = 0
        
        with open_csv_robust_with_fallback(artist_lineup_file) as f:
            reader = csv.DictReader(f)
            for row in reader:
                country = row.get('country', '').strip()
                if country:
                    country_band_counts[country] = country_band_counts.get(country, 0) + 1
                    total_bands += 1
        
        # Sort by band count descending, then by country name
        country_flags = {
            'United States': '🇺🇸', 'Germany': '🇩🇪', 'Sweden': '🇸🇪', 'Finland': '🇫🇮',
            'Italy': '🇮🇹', 'United Kingdom': '🇬🇧', 'Denmark': '🇩🇰', 'Andorra': '🇦🇩',
            'Austria': '🇦🇹', 'Faroe Islands': '🇫🇴', 'Greece': '🇬🇷', 'Norway': '🇳🇴',
            'Poland': '🇵🇱', 'Switzerland': '🇨🇭', 'Canada': '🇨🇦', 'Australia': '🇦🇺',
            'Brazil': '🇧🇷', 'Chile': '🇨🇱', 'Czech Republic': '🇨🇿', 'Ukraine': '🇺🇦',
            'Japan': '🇯🇵', 'Netherlands': '🇳🇱', 'Portugal': '🇵🇹', 'International': '🌍'
        }
        for country, count in sorted(country_band_counts.items(), key=lambda x: (-x[1], x[0])):
            pct = (count / total_bands * 100) if total_bands else 0
            flag = country_flags.get(country, '')
            display_name = f"{flag} {country}" if flag else country
            band_country_rows.append([display_name, str(count), f"{pct:.1f}%"])
        
        # Add total row
        band_country_rows.append(["Total", str(total_bands), "100.0%"])
    else:
        band_country_rows = [["No data available", "", ""]]

    # --- Band Repeats Report ---
    # Process artist lineup data for year-by-year breakdown
    band_repeats_rows = []
    band_repeats_headers = ["Year", "Band Count", "Percentage"]
    
    if artist_lineup_file.exists():
        year_band_counts = {}
        total_bands = 0
        
        with open_csv_robust_with_fallback(artist_lineup_file) as f:
            reader = csv.DictReader(f)
            for row in reader:
                band_name = (row.get('bandName') or '').strip()
                prior_years = (row.get('priorYears') or '').strip()
                
                if band_name:
                    total_bands += 1
                    
                    if prior_years and prior_years != 'Never':
                        # Split by space and count each year
                        years_list = prior_years.split()
                        for year in years_list:
                            year_band_counts[year] = year_band_counts.get(year, 0) + 1
                    else:
                        # Count "Never" as a year for this report
                        year_band_counts['Never'] = year_band_counts.get('Never', 0) + 1
        
        # Sort by band count descending, then by year (with "Never" at the end)
        def sort_key(item):
            year, count = item
            if year == 'Never':
                return (-count, 'zzz')  # Put "Never" at the end
            return (-count, year)
        
        for year, count in sorted(year_band_counts.items(), key=sort_key):
            pct = (count / total_bands * 100) if total_bands else 0
            band_repeats_rows.append([
                year,
                str(count),
                f"{pct:.1f}%"
            ])
    else:
        band_repeats_rows = [["No data available", "", ""]]

    # --- Top Band by Country Report ---
    # Find the top band for each country with at least 10 users
    # Only include actual bands from the current artist lineup
    top_band_by_country_rows = []
    top_band_by_country_headers = ["Country", "Top Band", "Must Votes", "Total Votes", "Must %"]
    
    # Load valid bands from lineup
    valid_bands = load_valid_bands_from_lineup(source)
    
    if artist_lineup_file.exists() and len(valid_bands) > 0:
        # First, get countries with at least 10 users
        country_user_counts = {}
        for user in filtered_users:
            country = user.get('country', '').strip()
            if country:
                country_user_counts[country] = country_user_counts.get(country, 0) + 1
        
        # Filter to countries with at least 10 users
        qualifying_countries = {country: count for country, count in country_user_counts.items() if count >= 10}
        
        # For each qualifying country, find the top band
        for country, user_count in sorted(qualifying_countries.items(), key=lambda x: -x[1]):
            # Get all users from this country
            country_user_ids = set()
            for user in filtered_users:
                if user.get('country', '').strip() == country:
                    user_id = user.get('userid')
                    if user_id:
                        country_user_ids.add(user_id)
            
            # Get band votes for this country's users
            country_band_votes = {}
            ranking_file = Path(static_files['rankingData'])
            if ranking_file.exists():
                with open_csv_robust_with_fallback(ranking_file) as f:
                    reader = csv.DictReader(f)
                    for row in reader:
                        user_id = row.get('userID')
                        user_id = extract_ranking_user_id(user_id, event_year)
                        band = row.get('bandName', '').strip()
                        ranking = row.get('ranking', '').strip().lower()
                        
                        # ONLY include bands that are in the valid lineup
                        if (user_id in country_user_ids and 
                            band and ranking in {'must', 'might', 'wont'} and
                            band.lower() in valid_bands):
                            
                            if band not in country_band_votes:
                                country_band_votes[band] = {'must': 0, 'might': 0, 'wont': 0}
                            
                            country_band_votes[band][ranking] += 1
            
            # Find the top band for this country (highest Must percentage)
            top_band = None
            top_must_pct = 0
            
            for band, votes in country_band_votes.items():
                total_votes = votes['must'] + votes['might'] + votes['wont']
                if total_votes >= 5:  # Only consider bands with at least 5 votes
                    must_pct = (votes['must'] / total_votes * 100) if total_votes else 0
                    if must_pct > top_must_pct:
                        top_must_pct = must_pct
                        top_band = band
            
            if top_band:
                votes = country_band_votes[top_band]
                total_votes = votes['must'] + votes['might'] + votes['wont']
                must_pct = (votes['must'] / total_votes * 100) if total_votes else 0
                
                top_band_by_country_rows.append([
                    country,
                    top_band,
                    str(votes['must']),
                    str(total_votes),
                    f"{must_pct:.1f}%"
                ])
    
    if not top_band_by_country_rows:
        top_band_by_country_rows = [["No data available", "", "", "", ""]]

    # --- Prepare for HTML ---
    # Check if Band Repeats should be hidden (only "Never" entries)
    band_repeats_should_hide = False
    if len(band_repeats_rows) == 1 and band_repeats_rows[0][0] == "Never":
        band_repeats_should_hide = True
        print("[DEBUG] Hiding Band Repeats tab - only contains 'Never' entries")
    
    processed_files = [
        ("Band Rankings", band_headers, band_rows_display, None),
        ("Country Report", country_headers, country_rows, None),
        ("Platform Report", platform_headers, platform_rows, None),
        ("Band Country", band_country_headers, band_country_rows, None),
    ]
    
    # Only add Band Repeats if it has meaningful data
    if not band_repeats_should_hide:
        processed_files.append(("Band Repeats", band_repeats_headers, band_repeats_rows, None))
    
    # ("Event Report", event_headers, event_rows, None),  # Hide event tab for now

    # Generate HTML content
    print("\nGenerating HTML...")
    # Add a last generated timestamp
    now = datetime.now()
    epoch = int(now.timestamp())
    
    # Try to get timezone name
    try:
        import time
        is_dst = time.daylight and time.localtime().tm_isdst > 0
        timezone_name = time.tzname[is_dst]
    except (IndexError, OSError):
        timezone_name = now.strftime('%Z')
        if not timezone_name:
            timezone_name = now.strftime('%z')
            if timezone_name:
                timezone_name = f"UTC{timezone_name[:3]}:{timezone_name[3:]}"
            else:
                timezone_name = "UTC"
    
    last_generated = now.strftime(f'%B %d, %Y at %I:%M %p {timezone_name}')
    last_generated_with_epoch = f'<span data-timestamp="{epoch}">{last_generated}</span>'
    html_content = generate_html_content(processed_files, last_generated_with_epoch, limit_country_rows=True)

    # Write HTML file
    output_path = Path('.') / output_file
    try:
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write(html_content)
        print(f"✓ HTML report generated successfully: {output_path}")
        print(f"  Open {output_path} in your web browser to view the dashboard.")
    except Exception as e:
        print(f"✗ Error writing HTML file: {e}")

    # Generate language-specific versions
    generate_all_language_files(processed_files, last_generated_with_epoch, source)


def load_valid_bands_from_lineup(source: str = '70K_Bands') -> set[str]:
    """
    Load the set of valid band names from the artist lineup file.
    For band rankings and reports, we need to validate against actual bands.
    
    Args:
        source: Data source ('70K_Bands' or 'MDF_Bands')
    
    Returns:
        Set of valid band names (case-insensitive) from the lineup
    """
    valid_bands = set()
    
    # Get file paths for this source
    file_paths = get_file_paths(source)
    lineup_file = Path(file_paths.get('artist_lineup', ''))
    
    if not lineup_file.exists():
        print(f"Warning: Artist lineup file not found at {lineup_file}")
        return valid_bands
    
    try:
        with open_csv_robust_with_fallback(lineup_file) as f:
            reader = csv.DictReader(f)
            for row in reader:
                band_name = row.get('bandName', '').strip()
                if band_name:
                    # Store in lowercase for case-insensitive comparison
                    valid_bands.add(band_name.lower())
        
        print(f"Loaded {len(valid_bands)} valid bands from lineup")
        return valid_bands
    except Exception as e:
        print(f"Error loading artist lineup file: {e}")
        import traceback
        traceback.print_exc()
        return valid_bands


def load_valid_events_from_schedule(source: str = '70K_Bands') -> dict[str, dict]:
    """
    Load the event details from the artist schedule file.
    For event attendance tracking, we need to map each unique event occurrence
    (band name + location + start time) to its full details.
    
    Args:
        source: Data source ('70K_Bands' or 'MDF_Bands')
    
    Returns:
        Dictionary mapping composite keys to event details:
        {
            'band_name_lower|location_lower|HH:MM': {
                'band_name': 'Original Band Name',
                'location': 'Location',
                'start_time': 'HH:MM',
                'full_name': 'Band Name - Location - Start Time',
                'event_type': 'Show' or 'Meet and Greet', etc.
            }
        }
    """
    valid_events = {}
    
    # Get file paths for this source
    file_paths = get_file_paths(source)
    schedule_file = Path(file_paths.get('artist_schedule', ''))
    
    if not schedule_file.exists():
        print(f"Warning: Artist schedule file not found at {schedule_file}")
        return valid_events
    
    try:
        with open_csv_robust_with_fallback(schedule_file) as f:
            reader = csv.DictReader(f)
            for row in reader:
                # Use 'Band' column from schedule file for event names
                event_name = row.get('Band', '').strip()
                location = row.get('Location', '').strip()
                start_time = row.get('Start Time', '').strip()
                event_type = row.get('Type', '').strip()
                
                if event_name and location and start_time:
                    # Create full event name: Band Name - Location - Start Time
                    full_name = f"{event_name} - {location} - {start_time}"
                    
                    # Create composite key for matching: "band_name|location|time"
                    # Normalize for case-insensitive matching
                    composite_key = f"{event_name.lower()}|{location.lower()}|{start_time}"
                    
                    # Store event details
                    valid_events[composite_key] = {
                        'band_name': event_name,
                        'location': location,
                        'start_time': start_time,
                        'full_name': full_name,
                        'event_type': event_type
                    }
        
        print(f"Loaded {len(valid_events)} unique event occurrences from schedule for attendance tracking")
        if len(valid_events) > 0:
            sample = list(valid_events.keys())[:5]
            print(f"Sample composite keys: {sample}")
        return valid_events
    except Exception as e:
        print(f"Error loading artist schedule file: {e}")
        import traceback
        traceback.print_exc()
        return valid_events


def main_full(source: str = '70K_Bands') -> None:
    """
    Main function to process CSV files and generate FULL HTML (no limits, with 48h active users tab).
    
    Args:
        source: Data source ('70K_Bands' or 'MDF_Bands')
    """
    # Get file paths based on source
    file_paths = get_file_paths(source)
    static_files = file_paths['static_files']
    event_year = file_paths.get('event_year', '')
    output_file = file_paths['output_full']
    
    print(f"Processing {source} data for full report...")
    print(f"Production pointer: {file_paths.get('pointer_path', '')}")
    print(f"Event year: {event_year}")
    print(f"Artist lineup: {file_paths.get('artist_lineup', '')}")
    print(f"Output file: {output_file}")

    # --- Platform Report ---
    platform_data = []
    user_count = 0
    platform_counts = {}
    user_file = Path(static_files['userData'])
    # --- Prepare date filtering ---
    now = datetime.now()
    cutoff = now - timedelta(days=30)
    filtered_users = []
    total_users = 0
    excluded_users = 0
    if user_file.exists():
        with open(user_file, 'r', encoding='utf-8', errors='replace') as f:
            reader = csv.DictReader(f)
            # Check if file has headers
            if reader.fieldnames is None:
                print(f"Warning: {user_file} appears to be empty or has no headers")
                return
            # Normalize fieldnames by stripping spaces
            reader.fieldnames = [fn.strip() for fn in reader.fieldnames]
            for i, row in enumerate(reader):
                # Normalize row keys as well
                row = {k.strip(): v for k, v in row.items()}
                total_users += 1
                last_launch_str = row.get('last launch', '').strip()
                try:
                    last_launch_dt = datetime.strptime(last_launch_str, '%Y-%m-%d %H:%M:%S')
                except Exception:
                    excluded_users += 1
                    continue  # skip rows with invalid or missing date
                if last_launch_dt < cutoff:
                    excluded_users += 1
                    continue  # skip users not active in last 30 days
                filtered_users.append(row)
    # Deduplicate filtered_users by userID (keep first occurrence)
    unique_users = {}
    for user in filtered_users:
        user_id = user.get('userid')
        if user_id and user_id not in unique_users:
            unique_users[user_id] = user
    filtered_users = list(unique_users.values())
    # Now build platform and country counts from filtered_users
    for row in filtered_users:
        platform = row.get('platform', '').strip()
        if platform:
            platform_counts[platform] = platform_counts.get(platform, 0) + 1
    user_count = len(filtered_users)
    platform_rows = []
    for plat, count in sorted(platform_counts.items(), key=lambda x: -x[1]):
        pct = (count / user_count * 100) if user_count else 0
        platform_rows.append([plat, f"{pct:.1f}%", str(count)])
    platform_rows.append(["Total", "", str(user_count)])
    platform_headers = ["Platform", "% of Users", "User Count"]

    # --- Country Report ---
    country_counts = {}
    for row in filtered_users:
        country = row.get('country', '').strip()
        if country:
            country_counts[country] = country_counts.get(country, 0) + 1
    # Store the number of unique countries for use in the HTML note
    import builtins
    builtins.country_count_unique = len(country_counts)
    user_count_country = len(filtered_users)
    country_rows = []
    for country, count in sorted(country_counts.items(), key=lambda x: -x[1]):
        pct = (count / user_count_country * 100) if user_count_country else 0
        country_rows.append([country, f"{pct:.1f}%", str(count)])
    # Do NOT append the Total row anymore
    country_headers = ["Country", "% of Users", "User Count"]

    # --- Band Ranking Report ---
    # Step 1: Load valid bands from artist lineup
    valid_bands = load_valid_bands_from_lineup(source)
    
    # Debug: Test if "Fri - Roof-Top Party" would be filtered out
    test_band = "Fri - Roof-Top Party"
    if is_valid_band(test_band, valid_bands):
        print(f"[DEBUG] WARNING: '{test_band}' is considered valid!")
    else:
        print(f"[DEBUG] '{test_band}' correctly filtered out")
    
    # Step 2: Build set of active user IDs
    active_user_ids = set()
    for user in filtered_users:
        user_id = user.get('userid')
        if user_id:
            active_user_ids.add(user_id)

    # Step 3: Process rankings for bands, only for active users and valid bands
    band_vote_counts = {}  # band -> {'must': int, 'might': int, 'wont': int}
    band_user_seen = {}    # band -> set of userIDs already counted
    darktq_must_userids = []
    unique_band_names = set()  # Track all unique bands regardless of votes
    filtered_out_bands = 0  # Track how many bands were filtered out
    ranking_file = Path(static_files['rankingData'])
    if ranking_file.exists():
        with open(ranking_file, 'r', encoding='utf-8', errors='replace') as f:
            reader = csv.DictReader(f)
            for row in reader:
                user_id = row.get('userID')
                user_id = extract_ranking_user_id(user_id, event_year)
                band = row.get('bandName', '').strip()
                if band:
                    unique_band_names.add(band)
                if not user_id or user_id not in active_user_ids:
                    continue  # skip if not an active user
                ranking = row.get('ranking', '').strip().lower()
                if not band or ranking not in {'must', 'might', 'wont'}:
                    continue
                
                # Filter out bands not in the artist lineup
                if band.lower() not in valid_bands:
                    filtered_out_bands += 1
                    continue
                
                if band not in band_vote_counts:
                    band_vote_counts[band] = {'must': 0, 'might': 0, 'wont': 0}
                    band_user_seen[band] = set()
                # Only count the first occurrence of a userID for a band
                if user_id not in band_user_seen[band]:
                    band_vote_counts[band][ranking] += 1
                    band_user_seen[band].add(user_id)
                # Collect userIDs for first 10 'Must' votes for 'Dark Tranquillity'
                if band.lower() == 'dark tranquillity' and ranking == 'must' and len(darktq_must_userids) < 10:
                    if user_id not in darktq_must_userids:
                        darktq_must_userids.append(user_id)
    
    print(f"[DEBUG] Filtered out {filtered_out_bands} band votes for bands not in artist lineup")
    
    # Debug: Check if "Fri - Roof-Top Party" is in the data
    if any('fri - roof-top party' in band.lower() for band in band_vote_counts.keys()):
        print("[DEBUG] WARNING: 'Fri - Roof-Top Party' found in band_vote_counts!")
        for band in band_vote_counts.keys():
            if 'fri - roof-top party' in band.lower():
                print(f"[DEBUG] Found problematic entry: '{band}' with votes: {band_vote_counts[band]}")
    
    # Print the user records for the first 10 'Must' votes for 'Dark Tranquillity'
    if darktq_must_userids:
        print('\n[DEBUG] First 10 user records for "Must" votes for Dark Tranquillity:')
        for i, uid in enumerate(darktq_must_userids):
            user_record = next((u for u in filtered_users if u.get('userid') == uid), None)
            print(f"  {i+1}. userID={uid}: {user_record}")
    band_rows = []
    print("\n[DEBUG] All bands and their vote counts for FULL report:")
    for band, votes in band_vote_counts.items():
        must_count = votes['must']
        might_count = votes['might']
        wont_count = votes['wont']
        total_votes = must_count + might_count + wont_count
        pct = (must_count / total_votes * 100) if total_votes else 0
        band_rows.append([band, f"{pct:.1f}%", str(must_count)])
        print(f"  Band: '{band}' | must: {must_count}, might: {might_count}, wont: {wont_count}, total: {total_votes}, %Must: {pct:.1f}%")
    # Sort by Must percentage descending, then band name
    band_rows = sorted(band_rows, key=lambda x: (-float(x[1].rstrip('%')), x[0]))
    band_headers = ["Rank", "Band Name", "% Must", "Must"]
    # Debug: print must, might, wont totals for top 5 bands
    print("\n[DEBUG] Must, Might, Wont totals for top 5 bands:")
    # Get the band names for the top 5 rows
    top5_band_names = [row[0] for row in band_rows[:5]]
    for band in top5_band_names:
        votes = band_vote_counts.get(band, {'must': 0, 'might': 0, 'wont': 0})
        print(f"  {band}: must={votes['must']}, might={votes['might']}, wont={votes['wont']}")

    # --- New Side-by-Side Table 1: OS Version ---
    ios_os_counts = {}
    android_os_counts = {}
    for u in filtered_users:
        platform = u.get('platform', '').strip().lower()
        os_version = u.get('osVersion', '').strip()
        if not os_version:
            continue
        if platform == 'ios':
            major_version = os_version.split('.')[0]
            ios_os_counts[major_version] = ios_os_counts.get(major_version, 0) + 1
        elif platform == 'android':
            android_os_counts[os_version] = android_os_counts.get(os_version, 0) + 1
    
    # Filter out "Unknown" entries unless they have more than 20 data points
    ios_os_list = [(ver, count) for ver, count in ios_os_counts.items() 
                   if ver.lower() != 'unknown' or count > 20]
    android_os_list = [(ver, count) for ver, count in android_os_counts.items() 
                       if ver.lower() != 'unknown' or count > 20]
    
    ios_os_list = sorted(ios_os_list, key=lambda x: (-x[1], x[0]))
    android_os_list = sorted(android_os_list, key=lambda x: (-x[1], x[0]))
    total_ios = sum(count for _, count in ios_os_list)
    total_android = sum(count for _, count in android_os_list)
    max_len = max(len(ios_os_list), len(android_os_list))
    # Pad lists to equal length
    ios_os_list += [('', 0)] * (max_len - len(ios_os_list))
    android_os_list += [('', 0)] * (max_len - len(android_os_list))
    side_by_side_os_rows = []
    for i in range(max_len):
        ios_ver, ios_count = ios_os_list[i]
        android_ver, android_count = android_os_list[i]
        ios_pct = f"{(ios_count / total_ios * 100):.1f}%" if ios_ver and total_ios else ''
        android_pct = f"{(android_count / total_android * 100):.1f}%" if android_ver and total_android else ''
        side_by_side_os_rows.append([
            ios_ver, str(ios_count) if ios_ver else '', ios_pct,
            android_ver, str(android_count) if android_ver else '', android_pct
        ])
    side_by_side_os_headers = ["iOS OS Version", "Count", "%", "Android OS Version", "Count", "%"]

    # --- New Side-by-Side Table 2: 70k Version ---
    ios_70k_counts = {}
    android_70k_counts = {}
    for u in filtered_users:
        platform = u.get('platform', '').strip().lower()
        v70k = u.get('70kVersion', '').strip()
        if not v70k:
            continue
        if platform == 'ios':
            ios_70k_counts[v70k] = ios_70k_counts.get(v70k, 0) + 1
        elif platform == 'android':
            android_70k_counts[v70k] = android_70k_counts.get(v70k, 0) + 1
    
    # Filter out "Unknown" entries unless they have more than 20 data points
    ios_70k_list = [(ver, count) for ver, count in ios_70k_counts.items() 
                    if ver.lower() != 'unknown' or count > 20]
    android_70k_list = [(ver, count) for ver, count in android_70k_counts.items() 
                        if ver.lower() != 'unknown' or count > 20]
    
    ios_70k_list = sorted(ios_70k_list, key=lambda x: (-x[1], x[0]))
    android_70k_list = sorted(android_70k_list, key=lambda x: (-x[1], x[0]))
    total_ios_70k = sum(count for _, count in ios_70k_list)
    total_android_70k = sum(count for _, count in android_70k_list)
    max_len_70k = max(len(ios_70k_list), len(android_70k_list))
    ios_70k_list += [('', 0)] * (max_len_70k - len(ios_70k_list))
    android_70k_list += [('', 0)] * (max_len_70k - len(android_70k_list))
    side_by_side_70k_rows = []
    for i in range(max_len_70k):
        ios_ver, ios_count = ios_70k_list[i]
        android_ver, android_count = android_70k_list[i]
        ios_pct = f"{(ios_count / total_ios_70k * 100):.1f}%" if ios_ver and total_ios_70k else ''
        android_pct = f"{(android_count / total_android_70k * 100):.1f}%" if android_ver and total_android_70k else ''
        side_by_side_70k_rows.append([
            ios_ver, str(ios_count) if ios_ver else '', ios_pct,
            android_ver, str(android_count) if android_ver else '', android_pct
        ])
    side_by_side_70k_headers = ["iOS 70K Version", "Count", "%", "Android 70K Version", "Count", "%"]

    # --- Band Country Report ---
    # Process artist lineup data for country breakdown
    artist_lineup_file = Path(file_paths['artist_lineup'])
    band_country_rows = []
    band_country_headers = ["Country", "Band Count", "Percentage"]
    
    if artist_lineup_file.exists():
        country_band_counts = {}
        total_bands = 0
        
        with open_csv_robust_with_fallback(artist_lineup_file) as f:
            reader = csv.DictReader(f)
            for row in reader:
                country = row.get('country', '').strip()
                if country:
                    country_band_counts[country] = country_band_counts.get(country, 0) + 1
                    total_bands += 1
        
        # Sort by band count descending, then by country name
        country_flags = {
            'United States': '🇺🇸', 'Germany': '🇩🇪', 'Sweden': '🇸🇪', 'Finland': '🇫🇮',
            'Italy': '🇮🇹', 'United Kingdom': '🇬🇧', 'Denmark': '🇩🇰', 'Andorra': '🇦🇩',
            'Austria': '🇦🇹', 'Faroe Islands': '🇫🇴', 'Greece': '🇬🇷', 'Norway': '🇳🇴',
            'Poland': '🇵🇱', 'Switzerland': '🇨🇭', 'Canada': '🇨🇦', 'Australia': '🇦🇺',
            'Brazil': '🇧🇷', 'Chile': '🇨🇱', 'Czech Republic': '🇨🇿', 'Ukraine': '🇺🇦',
            'Japan': '🇯🇵', 'Netherlands': '🇳🇱', 'Portugal': '🇵🇹', 'International': '🌍'
        }
        for country, count in sorted(country_band_counts.items(), key=lambda x: (-x[1], x[0])):
            pct = (count / total_bands * 100) if total_bands else 0
            flag = country_flags.get(country, '')
            display_name = f"{flag} {country}" if flag else country
            band_country_rows.append([display_name, str(count), f"{pct:.1f}%"])
        
        # Add total row
        band_country_rows.append(["Total", str(total_bands), "100.0%"])
    else:
        band_country_rows = [["No data available", "", ""]]

    # --- Band Repeats Report ---
    # Process artist lineup data for year-by-year breakdown
    band_repeats_rows = []
    band_repeats_headers = ["Year", "Band Count", "Percentage"]
    
    if artist_lineup_file.exists():
        year_band_counts = {}
        total_bands = 0
        
        with open_csv_robust_with_fallback(artist_lineup_file) as f:
            reader = csv.DictReader(f)
            for row in reader:
                band_name = (row.get('bandName') or '').strip()
                prior_years = (row.get('priorYears') or '').strip()
                
                if band_name:
                    total_bands += 1
                    
                    if prior_years and prior_years != 'Never':
                        # Split by space and count each year
                        years_list = prior_years.split()
                        for year in years_list:
                            year_band_counts[year] = year_band_counts.get(year, 0) + 1
                    else:
                        # Count "Never" as a year for this report
                        year_band_counts['Never'] = year_band_counts.get('Never', 0) + 1
        
        # Sort by band count descending, then by year (with "Never" at the end)
        def sort_key(item):
            year, count = item
            if year == 'Never':
                return (-count, 'zzz')  # Put "Never" at the end
            return (-count, year)
        
        for year, count in sorted(year_band_counts.items(), key=sort_key):
            pct = (count / total_bands * 100) if total_bands else 0
            band_repeats_rows.append([
                year,
                str(count),
                f"{pct:.1f}%"
            ])
    else:
        band_repeats_rows = [["No data available", "", ""]]

    # --- Top Band by Country Report ---
    # Find the top band for each country with at least 10 users
    # Only include actual bands from the current artist lineup
    top_band_by_country_rows = []
    top_band_by_country_headers = ["Country", "Top Band", "Must Votes", "Total Votes", "Must %"]
    
    # Load valid bands from lineup
    valid_bands = load_valid_bands_from_lineup(source)
    
    if artist_lineup_file.exists() and len(valid_bands) > 0:
        # First, get countries with at least 10 users
        country_user_counts = {}
        for user in filtered_users:
            country = user.get('country', '').strip()
            if country:
                country_user_counts[country] = country_user_counts.get(country, 0) + 1
        
        # Filter to countries with at least 10 users
        qualifying_countries = {country: count for country, count in country_user_counts.items() if count >= 10}
        
        # For each qualifying country, find the top band
        for country, user_count in sorted(qualifying_countries.items(), key=lambda x: -x[1]):
            # Get all users from this country
            country_user_ids = set()
            for user in filtered_users:
                if user.get('country', '').strip() == country:
                    user_id = user.get('userid')
                    if user_id:
                        country_user_ids.add(user_id)
            
            # Get band votes for this country's users
            country_band_votes = {}
            ranking_file = Path(static_files['rankingData'])
            if ranking_file.exists():
                with open_csv_robust(ranking_file) as f:
                    reader = csv.DictReader(f)
                    for row in reader:
                        user_id = row.get('userID')
                        user_id = extract_ranking_user_id(user_id, event_year)
                        band = row.get('bandName', '').strip()
                        ranking = row.get('ranking', '').strip().lower()
                        
                        # ONLY include bands that are in the valid lineup
                        if (user_id in country_user_ids and 
                            band and ranking in {'must', 'might', 'wont'} and
                            band.lower() in valid_bands):
                            
                            if band not in country_band_votes:
                                country_band_votes[band] = {'must': 0, 'might': 0, 'wont': 0}
                            
                            country_band_votes[band][ranking] += 1
            
            # Find the top band for this country (highest Must percentage)
            top_band = None
            top_must_pct = 0
            
            for band, votes in country_band_votes.items():
                total_votes = votes['must'] + votes['might'] + votes['wont']
                if total_votes >= 5:  # Only consider bands with at least 5 votes
                    must_pct = (votes['must'] / total_votes * 100) if total_votes else 0
                    if must_pct > top_must_pct:
                        top_must_pct = must_pct
                        top_band = band
            
            if top_band:
                votes = country_band_votes[top_band]
                total_votes = votes['must'] + votes['might'] + votes['wont']
                must_pct = (votes['must'] / total_votes * 100) if total_votes else 0
                
                top_band_by_country_rows.append([
                    country,
                    top_band,
                    str(votes['must']),
                    str(total_votes),
                    f"{must_pct:.1f}%"
                ])
    
    if not top_band_by_country_rows:
        top_band_by_country_rows = [["No data available", "", "", "", ""]]

    # --- Event Attendance Report ---
    # Load valid events from schedule
    valid_events = load_valid_events_from_schedule(source)
    
    event_attendance_headers = ["Event", "# Attended", "Total Users", "% Attended", "Est. Attendance"]
    event_attendance_rows = []
    
    # Only process data for the current event year from the production pointer
    current_year = str(event_year)
    
    # Read event data from JSON showData
    bands_data_file = Path(static_files.get('bandsData', ''))
    if bands_data_file.exists() and len(valid_events) > 0:
        event_counts = {}  # full_event_name -> count of users who attended
        event_users_seen = {}  # full_event_name -> set of userIDs (to deduplicate)
        user_event_counts = {}  # user_id -> count of events they have in schedule
        
        total_event_rows = 0
        skipped_inactive = 0
        skipped_invalid = 0
        
        try:
            with open(bands_data_file, 'r', encoding='utf-8') as f:
                json_data = json.load(f)
            
            # Access the showData section
            show_data = json_data.get('showData', {})
            
            # FIRST PASS: Count how many events each active user has in their 2026 schedule
            # This determines the "Total Users" denominator (users with >10 events)
            for user_id, user_shows in show_data.items():
                # Skip if user is not active in last 30 days
                if user_id not in active_user_ids:
                    continue
                
                # Skip if user_shows is not a dict (safety check)
                if not isinstance(user_shows, dict):
                    continue
                
                year_2026 = user_shows.get(current_year, {})
                if isinstance(year_2026, dict):
                    # Count valid events for this user
                    valid_event_count = 0
                    for event_key, event_data in year_2026.items():
                        band_name = event_data.get('bandName', '').strip()
                        location = event_data.get('location', '').strip()
                        start_hour = event_data.get('startTimeHour', '')
                        start_min = event_data.get('startTimeMin', '')
                        
                        try:
                            if start_hour != '' and start_min != '':
                                start_time = f"{int(start_hour):02d}:{int(start_min):02d}"
                            else:
                                continue
                        except (ValueError, TypeError):
                            continue
                        
                        composite_key = f"{band_name.lower()}|{location.lower()}|{start_time}"
                        
                        # Only count events that exist in the schedule
                        if composite_key in valid_events:
                            valid_event_count += 1
                    
                    user_event_counts[user_id] = valid_event_count
            
            # Filter to users with more than 10 events in their schedule
            qualified_users = {uid for uid, count in user_event_counts.items() if count > 10}
            total_qualified_users = len(qualified_users)
            
            print(f"[DEBUG] Event attendance - users with >10 events in schedule: {total_qualified_users} out of {len(user_event_counts)} active users")
            
            # SECOND PASS: Count attendance for each event
            # Loop through all users in showData
            for user_id, user_shows in show_data.items():
                # Skip if user is not active in last 30 days
                if user_id not in active_user_ids:
                    continue
                
                # Skip if user_shows is not a dict (safety check)
                if not isinstance(user_shows, dict):
                    print(f"[DEBUG] Skipping non-dict user_shows for user {user_id}, type={type(user_shows)}")
                    continue
                
                # Loop through all years for this user
                for year, events in user_shows.items():
                    # ONLY process current year (2026)
                    if year != current_year:
                        continue
                    
                    # Skip if events is not a dict (safety check)
                    if not isinstance(events, dict):
                        print(f"[DEBUG] Skipping non-dict events for user {user_id}, year {year}, type={type(events)}")
                        continue
                    
                    # Loop through all events for this year
                    for event_key, event_data in events.items():
                        total_event_rows += 1
                        
                        # Extract event details from showData
                        band_name = event_data.get('bandName', '').strip()
                        location = event_data.get('location', '').strip()
                        start_hour = event_data.get('startTimeHour', '')
                        start_min = event_data.get('startTimeMin', '')
                        status = event_data.get('status', '').strip()
                        
                        # Build start time in HH:MM format from hour and minute
                        try:
                            if start_hour != '' and start_min != '':
                                start_time = f"{int(start_hour):02d}:{int(start_min):02d}"
                            else:
                                # Missing time data, skip this event
                                skipped_invalid += 1
                                continue
                        except (ValueError, TypeError):
                            # Invalid time data
                            skipped_invalid += 1
                            continue
                        
                        # Create composite key to match against schedule
                        # Format: "band_name|location|HH:MM" (case-insensitive)
                        composite_key = f"{band_name.lower()}|{location.lower()}|{start_time}"
                        
                        # Skip if this specific event occurrence is not in the schedule
                        if composite_key not in valid_events:
                            skipped_invalid += 1
                            continue
                        
                        # Get the full event name from the schedule data
                        event_info = valid_events[composite_key]
                        full_event_name = event_info['full_name']
                        
                        # Parse status (could be "sawAll", "sawSome", "sawAll:timestamp", etc.)
                        status_type = status.split(':')[0] if ':' in status else status
                        
                        # Only process sawAll and sawSome (combine them as "attended")
                        if status_type not in ['sawAll', 'sawSome']:
                            continue
                        
                        # Initialize counters for this specific event occurrence
                        if full_event_name not in event_counts:
                            event_counts[full_event_name] = 0
                            event_users_seen[full_event_name] = set()
                        
                        # Only count each user once per event occurrence
                        if user_id not in event_users_seen[full_event_name]:
                            event_counts[full_event_name] += 1
                            event_users_seen[full_event_name].add(user_id)
            
            # Count skipped inactive users
            for user_id in show_data.keys():
                if user_id not in active_user_ids:
                    skipped_inactive += 1
            
            print(f"[DEBUG] Event attendance (year {current_year} only): total rows={total_event_rows}, skipped_inactive={skipped_inactive}, skipped_invalid={skipped_invalid}, events_with_data={len(event_counts)}, total_qualified_users={total_qualified_users}")
            
            # Create rows sorted by attendance count descending
            for full_event_name, attended_count in sorted(event_counts.items(), 
                                                          key=lambda x: x[1], 
                                                          reverse=True):
                # Calculate percentage based on total qualified users (active + >10 events in schedule)
                pct_attended = (attended_count / total_qualified_users * 100) if total_qualified_users > 0 else 0
                
                # Calculate estimated total attendance by applying the percentage to the total user base
                estimated_attendance = int((pct_attended / 100) * TOTAL_USER_BASE_FOR_ATTENDANCE)
                
                event_attendance_rows.append([
                    full_event_name,
                    str(attended_count),
                    str(total_qualified_users),
                    f"{pct_attended:.1f}%",
                    str(estimated_attendance)
                ])
            
            print(f"[DEBUG] Processed attendance data for {len(event_attendance_rows)} events")
        
        except Exception as e:
            print(f"Error reading event data from JSON: {e}")
            import traceback
            traceback.print_exc()
            event_attendance_rows = [["Error loading data", "", "", "", ""]]
    else:
        if len(valid_events) == 0:
            event_attendance_rows = [["No valid events in schedule", "", "", "", ""]]
        else:
            event_attendance_rows = [["No event data available", "", "", "", ""]]

    # --- Platform by Country Report ---
    # Show platform distribution by country
    platform_by_country_rows = []
    platform_by_country_headers = ["Country", "User Count", "iOS %", "Android %"]
    
    # Group users by country and count platforms
    country_platform_counts = {}
    for user in filtered_users:
        country = user.get('country', '').strip()
        platform = user.get('platform', '').strip().lower()
        
        if country and platform in ['ios', 'android']:
            if country not in country_platform_counts:
                country_platform_counts[country] = {'ios': 0, 'android': 0, 'total': 0}
            
            country_platform_counts[country][platform] += 1
            country_platform_counts[country]['total'] += 1
    
    # Calculate percentages and create rows, sorted by user count descending
    for country, counts in sorted(country_platform_counts.items(), key=lambda x: x[1]['total'], reverse=True):
        total = counts['total']
        
        if total >= 5:  # Only show countries with at least 5 users
            ios_pct = (counts['ios'] / total * 100) if total else 0
            android_pct = (counts['android'] / total * 100) if total else 0
            
            platform_by_country_rows.append([
                country,
                str(total),
                f"{ios_pct:.1f}%",
                f"{android_pct:.1f}%"
            ])
    
    if not platform_by_country_rows:
        platform_by_country_rows = [["No data available", "", ""]]

    # --- Daily Usage Report ---
    daily_usage_headers = ["Date", "Active Users"]
    daily_usage_rows = []
    
    # --- Monthly Usage Report ---
    monthly_usage_headers = ["Month", "iOS %", "Android %", "Total Users"]
    monthly_usage_rows = []
    
    # Load usage trackers for both 70K_Bands and MDF_Bands sources
    try:
        from reporting.usage import DailyUsageTracker, MonthlyUsageTracker

        if _FESTIVAL_CONTEXT is None:
            raise RuntimeError("Festival context not set")

        daily_tracker = DailyUsageTracker(_FESTIVAL_CONTEXT)
        monthly_tracker = MonthlyUsageTracker(_FESTIVAL_CONTEXT)
        
        # Get historical data
        headers, data = daily_tracker.get_daily_usage_data()
        daily_usage_rows = data
        
        # Check if today's data is already in historical data
        today_str = datetime.now().strftime('%b %d')
        today_in_history = any(row[0] == today_str for row in daily_usage_rows)
        
        # Only add current day's usage if it's not already in historical data
        if not today_in_history:
            current_usage = daily_tracker.get_current_day_usage()
            if current_usage > 0:
                daily_usage_rows.insert(0, [today_str, str(current_usage)])
        
        # Monthly usage tracker
        monthly_headers, monthly_data = monthly_tracker.get_monthly_usage_data()
        monthly_usage_rows = monthly_data
            
    except ImportError as e:
        print(f"Warning: Could not import usage trackers: {e}")
        daily_usage_rows = [["No data available", ""]]
        monthly_usage_rows = [["No data available", "", "", ""]]
    except Exception as e:
        print(f"Warning: Error getting usage data: {e}")
        daily_usage_rows = [["No data available", ""]]
        monthly_usage_rows = [["No data available", "", "", ""]]

    # --- Active Profiles Report ---
    profile_counts = {}
    for row in filtered_users:
        profiles = row.get('activeProfiles', '').strip()
        # Treat empty/null as 0
        if not profiles or profiles == '':
            profiles = '0'
        # Convert to int for comparison
        try:
            profile_num = int(profiles)
        except ValueError:
            profile_num = 0
        
        # Combine 0 and 1 (both represent default/no custom profiles)
        if profile_num <= 1:
            key = '0-1 (Default)'
        else:
            key = profiles
        
        profile_counts[key] = profile_counts.get(key, 0) + 1
    
    # Sort by user count descending
    profile_rows = []
    for num_profiles, user_count in sorted(profile_counts.items(), key=lambda x: -x[1]):
        profile_rows.append([num_profiles, str(user_count)])
    
    profile_headers = ["Num Profiles", "User Count"]
    
    # --- Prepare for HTML ---
    processed_files = [
        ("Band Rankings", band_headers, band_rows, None),
        ("Country Report", country_headers, country_rows, None),
        ("Platform Report", platform_headers, platform_rows, None),
        ("Band Country", band_country_headers, band_country_rows, None),
        ("Band Repeats", band_repeats_headers, band_repeats_rows, None),
        ("Top Band by Country", top_band_by_country_headers, top_band_by_country_rows, None),
        ("Platform by Country", platform_by_country_headers, platform_by_country_rows, None),
        ("Event Attendance", event_attendance_headers, event_attendance_rows, None),
        ("Daily Usage", daily_usage_headers, daily_usage_rows, None),
        ("Monthly Usage", monthly_usage_headers, monthly_usage_rows, None),
        ("OS Version", side_by_side_os_headers, side_by_side_os_rows, None),
        ("70K Version", side_by_side_70k_headers, side_by_side_70k_rows, None),
        ("Active Profiles", profile_headers, profile_rows, None),
    ]

    # Generate HTML content
    now = datetime.now()
    epoch = int(now.timestamp())
    
    # Try to get timezone name
    try:
        import time
        is_dst = time.daylight and time.localtime().tm_isdst > 0
        timezone_name = time.tzname[is_dst]
    except (IndexError, OSError):
        timezone_name = now.strftime('%Z')
        if not timezone_name:
            timezone_name = now.strftime('%z')
            if timezone_name:
                timezone_name = f"UTC{timezone_name[:3]}:{timezone_name[3:]}"
            else:
                timezone_name = "UTC"
    
    last_generated = now.strftime(f'%B %d, %Y at %I:%M %p {timezone_name}')
    last_generated_with_epoch = f'<span data-timestamp="{epoch}">{last_generated}</span>'
    html_content = generate_html_content(processed_files, last_generated_with_epoch, limit_country_rows=False)

    # Change title and visible dashboard title for the full report
    full_title = dashboard_title("Stats Full", event_year)
    html_content = html_content.replace('<title>Stats</title>', f'<title>{html.escape(full_title)}</title>')
    html_content = html_content.replace(
        'data-en="Stats">Stats<',
        f'data-en="Stats">{html.escape(full_title)}<',
    )

    # Debug: Print the HTML row for Dodheimsgard if present
    dodheimsgard_row = None
    for row in band_rows:
        if row[0].strip().lower() == 'dodheimsgard':
            dodheimsgard_row = row
            break
    if dodheimsgard_row:
        # Manually generate the HTML for this row as in generate_table_html
        html_row = '<tr>'
        for i, cell in enumerate(dodheimsgard_row):
            cell_value = escape_html(cell)
            cell_class = ' class="number-cell"' if cell.replace('.', '').replace('%', '').replace(',', '').isdigit() else ''
            html_row += f'<td{cell_class}>{cell_value}</td>'
        html_row += '</tr>'
        print(f"[DEBUG] HTML row for Dodheimsgard in FULL report:\n{html_row}")
    else:
        print("[DEBUG] Dodheimsgard not found in band_rows for FULL report!")

    # Write HTML file
    output_file_path = Path('.') / output_file
    try:
        with open(output_file_path, 'w', encoding='utf-8') as f:
            f.write(html_content)
        print(f"✓ FULL HTML report generated successfully: {output_file}")
        print(f"  Open {output_file} in your web browser to view the dashboard.")
    except Exception as e:
        print(f"✗ Error writing FULL HTML file: {e}")




if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="CSV to HTML Report Generator")
    parser.add_argument('-f', '--file', type=str, help='Output HTML file name for the main report')
    parser.add_argument('--source', choices=['70K_Bands', 'MDF_Bands'], default='70K_Bands', 
                       help='Data source to process (default: 70K_Bands)')
    parser.add_argument('--min-votes', type=int, default=50, 
                       help='Bands need more than this many Must votes to appear in the main report (default: 50)')
    args = parser.parse_args()
    
    print(f"Generating reports for {args.source}...")
    main(output_file=args.file, source=args.source, min_votes=args.min_votes)
    main_full(source=args.source)
