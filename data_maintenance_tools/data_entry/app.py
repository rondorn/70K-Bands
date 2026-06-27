"""Flask web application for festival band and schedule data entry."""

from __future__ import annotations

import html
from pathlib import Path
from typing import Any
from urllib.parse import quote

from flask import Flask, jsonify, redirect, render_template, request, url_for

from data_entry.band_logic import (
    append_band,
    build_metal_archives_search_url,
    build_wikipedia_search_url,
    build_youtube_search_url,
    check_duplicate,
    normalize_https_prefix,
    strip_image_url_numeric_query,
    validate_band_data,
)
from data_entry.config_store import (
    active_festival_id,
    config_path,
    create_new_festival,
    ensure_data_files,
    list_festivals,
    list_from_textarea,
    load_config,
    resolve_path,
    resolved_paths,
    save_config,
    set_active_festival,
    textarea_from_list,
)
from data_entry.directory_picker import choose_directory
from data_entry.description_notes import save_description_note
from data_entry.discover import discover_band
from data_entry.pointer import introspect_pointer
from data_entry.schedule_logic import (
    EVENT_LENGTH_ARRAY,
    HOUR_ARRAY,
    MIN_ARRAY,
    NON_BAND_EVENT_TYPES,
    ScheduleEvent,
    append_schedule_event,
    band_name_options,
    build_event_from_form,
    event_to_form,
    read_schedule,
    remove_matching_event,
    replace_matching_event,
    validate_event,
    write_schedule,
)

TEMPLATE_DIR = Path(__file__).resolve().parent / "templates"
STATIC_DIR = Path(__file__).resolve().parent / "static"


def create_app() -> Flask:
    app = Flask(__name__, template_folder=str(TEMPLATE_DIR), static_folder=str(STATIC_DIR))

    @app.context_processor
    def inject_globals() -> dict[str, Any]:
        cfg = load_config()
        paths = resolved_paths(cfg)
        return {
            "festival_name": cfg.get("festival_name") or "Festival Data Entry",
            "config_file": str(config_path()),
            "lineup_file": paths.get("lineup_file", ""),
            "schedule_file": paths.get("schedule_file", ""),
        }

    @app.get("/")
    def home():
        return redirect(url_for("schedule_entry"))

    @app.route("/config", methods=["GET", "POST"])
    def config_page():
        switch_id = request.args.get("switch", "").strip()
        if switch_id:
            try:
                set_active_festival(switch_id)
            except ValueError as exc:
                return render_template(
                    "config.html",
                    cfg=load_config(),
                    active_festival_id=active_festival_id(),
                    festivals=list_festivals(),
                    multiple_festivals=False,
                    venues_text="",
                    dates_text="",
                    days_text="",
                    event_types_text="",
                    message="",
                    error=str(exc),
                )
            return redirect(url_for("config_page"))

        cfg = load_config()
        message = ""
        error = ""
        current_festival_id = active_festival_id()

        if request.method == "POST":
            config_action = request.form.get("config_action", "save")
            if config_action == "new":
                current_cfg = _config_from_form(request.form)
                current_cfg["_festival_id"] = request.form.get("festival_id", "").strip()
                create_new_festival(save_current=current_cfg)
                return redirect(url_for("config_page"))

            cfg = _config_from_form(request.form)
            current_festival_id = save_config(
                cfg, festival_id=request.form.get("festival_id", "").strip() or None
            )
            ensure_data_files(cfg)
            message = "Configuration saved."
            cfg = load_config()

        festivals = list_festivals()
        return render_template(
            "config.html",
            cfg=cfg,
            active_festival_id=current_festival_id or active_festival_id(),
            festivals=festivals,
            multiple_festivals=len(festivals) > 1,
            venues_text=textarea_from_list(cfg.get("venues", [])),
            dates_text=textarea_from_list(cfg.get("dates", [])),
            days_text=textarea_from_list(cfg.get("days", [])),
            event_types_text=textarea_from_list(cfg.get("event_types", [])),
            message=message,
            error=error,
        )

    @app.get("/api/introspect")
    def api_introspect():
        pointer_url = request.args.get("pointer_url", "").strip()
        if not pointer_url:
            return jsonify({"ok": False, "error": "pointer_url is required"}), 400
        try:
            hints = introspect_pointer(pointer_url)
            return jsonify({"ok": True, "hints": hints})
        except Exception as exc:
            return jsonify({"ok": False, "error": str(exc)}), 400

    @app.post("/api/save-description-note")
    def api_save_description_note():
        paths = resolved_paths(load_config())
        notes_dir_input = request.form.get("notes_directory", "").strip()
        notes_dir = (
            resolve_path(notes_dir_input, config_path().parent)
            if notes_dir_input
            else paths.get("notes_directory", "")
        )
        label = request.form.get("note_label", "").strip()
        content = request.form.get("note_text", "")
        try:
            saved_path = save_description_note(notes_dir, label, content)
            return jsonify(
                {
                    "ok": True,
                    "path": str(saved_path),
                    "filename": saved_path.name,
                    "message": (
                        f"Saved {saved_path.name}. Add a Dropbox share link for this file to the "
                        "description map CSV (Band, URL, Date) when you have access."
                    ),
                }
            )
        except Exception as exc:
            return jsonify({"ok": False, "error": str(exc)}), 400

    @app.post("/api/choose-directory")
    def api_choose_directory():
        initial_dir = request.form.get("initial_dir", "").strip()
        title = request.form.get("title", "Choose a folder").strip() or "Choose a folder"
        try:
            path = choose_directory(initial_dir, title)
            if not path:
                return jsonify({"ok": False, "cancelled": True})
            return jsonify({"ok": True, "path": path})
        except Exception as exc:
            return jsonify({"ok": False, "error": str(exc)}), 400

    @app.route("/schedule", methods=["GET", "POST"])
    def schedule_entry():
        cfg = load_config()
        paths = resolved_paths(cfg)
        schedule_path = paths["schedule_file"]
        existing = read_schedule(schedule_path)

        form = {
            "BandName": request.values.get("BandName", ""),
            "EventType": request.values.get("EventType", "") or "Show",
            "Venue": request.values.get("Venue", ""),
            "Date": request.values.get("Date", ""),
            "Day": request.values.get("Day", ""),
            "StartHour": request.values.get("StartHour", ""),
            "StartMin": request.values.get("StartMin", ""),
            "EndHour": request.values.get("EndHour", ""),
            "EndMin": request.values.get("EndMin", ""),
            "EventLength": request.values.get("EventLength", ""),
            "Notes": request.values.get("Notes", ""),
            "DescriptionText": request.values.get("DescriptionText", ""),
            "ImageURL": request.values.get("ImageURL", ""),
            "OrigBand": request.values.get("OrigBand", ""),
            "OrigVenue": request.values.get("OrigVenue", ""),
            "OrigDate": request.values.get("OrigDate", ""),
            "OrigStartTime": request.values.get("OrigStartTime", ""),
        }

        edit_index = request.values.get("editIndex", "")
        if request.method == "GET" and edit_index.isdigit():
            idx = int(edit_index)
            if 0 <= idx < len(existing):
                form = event_to_form(existing[idx])

        modify_mode = bool(form.get("OrigBand") or request.values.get("modifyMode"))

        confirm = ""
        confirm_message = request.values.get("confirmMessage", "")
        confirm_html = request.values.get("confirm", "")
        errors: list[str] = []

        if request.method == "POST" and request.form.get("Submit"):
            event = build_event_from_form(request.form, cfg)
            verify_bypass = bool(request.form.get("verifyBypass"))
            orig_band = request.form.get("OrigBand", "").strip()
            orig_venue = request.form.get("OrigVenue", "").strip()
            orig_date = request.form.get("OrigDate", "").strip()
            orig_start = request.form.get("OrigStartTime", "").strip()
            is_update = bool(orig_band and orig_venue and orig_date and orig_start)
            exclude = (orig_band, orig_venue, orig_date, orig_start) if is_update else None
            errors = validate_event(
                event, existing, cfg, verify_bypass=verify_bypass, exclude=exclude
            )
            if not errors:
                if is_update:
                    updated = replace_matching_event(
                        existing,
                        orig_band,
                        orig_venue,
                        orig_date,
                        orig_start,
                        event,
                    )
                    write_schedule(schedule_path, updated)
                    confirm_message = f"{event.band} has been updated"
                else:
                    append_schedule_event(schedule_path, event)
                    confirm_message = f"{event.band} has been added"
                description_note_message = ""
                if event.event_type in NON_BAND_EVENT_TYPES:
                    description_text = request.form.get("DescriptionText", "")
                    notes_dir = paths.get("notes_directory", "")
                    if description_text.strip() and notes_dir:
                        try:
                            saved_note = save_description_note(
                                notes_dir, event.band, description_text
                            )
                            description_note_message = (
                                f" Description note saved as {saved_note.name}."
                            )
                        except Exception as exc:
                            description_note_message = (
                                f" Description note not saved: {exc}"
                            )
                    elif description_text.strip() and not notes_dir:
                        description_note_message = (
                            " Description not saved: set Notes directory on the Config screen."
                        )
                confirm_message += description_note_message
                confirm_html = (
                    f"Band={html.escape(event.band)}<br>"
                    f"Venue={html.escape(event.location)}<br>"
                    f"Day={html.escape(event.day)}<br>"
                    f"Date={html.escape(event.date)}<br>"
                    f"Start Time={html.escape(event.start_time)}<br>"
                    f"End Time={html.escape(event.end_time)}<br>"
                    f"Notes={html.escape(event.notes)}<br>"
                    f"ImageURL={html.escape(event.image_url)}<br>"
                )
                form = _preserve_schedule_defaults(request.form)
                modify_mode = False
            else:
                confirm_message = "<br>".join(errors)
                form = dict(request.form)
                modify_mode = is_update

        bands = band_name_options(cfg, paths)
        return render_template(
            "schedule_entry.html",
            form=form,
            bands=bands,
            venues=cfg.get("venues", []),
            dates=cfg.get("dates", []),
            days=cfg.get("days", []),
            event_types=cfg.get("event_types", []),
            description_map_url=cfg.get("description_map_url", ""),
            notes_directory=paths.get("notes_directory", ""),
            hour_array=[" ", *HOUR_ARRAY],
            min_array=["  ", *MIN_ARRAY],
            event_length_array=EVENT_LENGTH_ARRAY,
            confirm=confirm_html,
            confirm_message=confirm_message,
            errors=errors,
            modify_mode=modify_mode,
        )

    @app.post("/schedule/remove")
    def schedule_remove():
        cfg = load_config()
        paths = resolved_paths(cfg)
        band = request.form.get("band", "").strip()
        venue = request.form.get("venue", "").strip()
        date = request.form.get("date", "").strip()
        start_time = request.form.get("start_time", "").strip()
        return_to = request.form.get("return_to", "schedule_entry")

        if not all([band, venue, date, start_time]):
            confirm = request.form.get("confirm", "")
            for line in confirm.split("<br>"):
                if line.startswith("Band="):
                    band = line[5:]
                elif line.startswith("Venue="):
                    venue = line[6:]
                elif line.startswith("Date="):
                    date = line[5:]
                elif line.startswith("Start Time="):
                    start_time = line[11:]

        events = read_schedule(paths["schedule_file"])
        updated = remove_matching_event(events, band, venue, date, start_time)
        write_schedule(paths["schedule_file"], updated)
        if return_to == "schedule_view":
            return redirect(url_for("schedule_view", message="Entry removed"))
        return redirect(url_for("schedule_entry"))

    @app.get("/schedule/view")
    def schedule_view():
        cfg = load_config()
        paths = resolved_paths(cfg)
        events = read_schedule(paths["schedule_file"])
        return render_template(
            "schedule_view.html",
            events=events,
            message=request.args.get("message", ""),
        )

    @app.get("/schedule/stats")
    def schedule_stats():
        cfg = load_config()
        paths = resolved_paths(cfg)
        events = read_schedule(paths["schedule_file"])
        bands = band_name_options(cfg, paths)
        stats: dict[str, dict[str, int]] = {}
        for event in events:
            stats.setdefault(event.band, {})
            stats[event.band][event.event_type] = stats[event.band].get(event.event_type, 0) + 1
        return render_template(
            "schedule_stats.html",
            bands=[b for b in bands if b.strip()],
            stats=stats,
            event_types=cfg.get("event_types", []),
            total_events=len(events),
        )

    @app.route("/bands", methods=["GET", "POST"])
    def band_entry():
        cfg = load_config()
        paths = resolved_paths(cfg)
        form_data = {key: request.values.get(key, "") for key in _band_form_fields(cfg)}
        form_data["latestAlbum"] = request.values.get("latestAlbum", "")
        form_data["musicBrainz"] = request.values.get("musicBrainz", "")
        errors: list[str] = []
        success = False

        if request.method == "POST" and request.form.get("action") == "submit":
            csv_data = {k: request.form.get(k, "").strip() for k in _band_form_fields(cfg)}
            latest_album = request.form.get("latestAlbum", "").strip()
            csv_data["officalSite"] = normalize_https_prefix(csv_data.get("officalSite", ""))
            csv_data["imageUrl"] = normalize_https_prefix(
                strip_image_url_numeric_query(csv_data.get("imageUrl", ""))
            )
            band_name = csv_data.get("bandName", "").strip()
            if band_name:
                if not csv_data.get("wikipedia"):
                    csv_data["wikipedia"] = build_wikipedia_search_url(band_name)
                csv_data["youtube"] = build_youtube_search_url(band_name, latest_album)
                if not csv_data.get("metalArchives"):
                    csv_data["metalArchives"] = build_metal_archives_search_url(band_name)

            ok, errors = validate_band_data(csv_data)
            if ok and check_duplicate(band_name, paths["lineup_file"]):
                ok = False
                errors.append(f"Band '{band_name}' already exists in the lineup file")

            if ok:
                append_band(csv_data, paths["lineup_file"], cfg)
                success = True
                form_data = {k: "" for k in form_data}
            else:
                form_data = {**csv_data, "latestAlbum": latest_album}

        return render_template(
            "band_entry.html",
            form_data=form_data,
            include_prior_years=bool(cfg.get("include_prior_years_field")),
            errors=errors,
            success=success,
        )

    @app.get("/bands/discover")
    def band_discover():
        result = discover_band(
            metal_archives_url=request.args.get("metalArchives", ""),
            musicbrainz_url=request.args.get("musicBrainz", ""),
            band_name=request.args.get("bandName", ""),
        )
        if not result.get("ok"):
            return jsonify(result), 400
        return jsonify(result)

    return app


def _config_from_form(form) -> dict[str, Any]:
    return {
        "festival_name": form.get("festival_name", "").strip(),
        "pointer_url": form.get("pointer_url", "").strip(),
        "event_year": form.get("event_year", "").strip(),
        "lineup_file": form.get("lineup_file", "").strip(),
        "schedule_file": form.get("schedule_file", "").strip(),
        "band_list_url": form.get("band_list_url", "").strip(),
        "description_map_url": form.get("description_map_url", "").strip(),
        "notes_directory": form.get("notes_directory", "").strip(),
        "include_prior_years_field": bool(form.get("include_prior_years_field")),
        "venues": list_from_textarea(form.get("venues_text", "")),
        "dates": list_from_textarea(form.get("dates_text", "")),
        "days": list_from_textarea(form.get("days_text", "")),
        "event_types": list_from_textarea(form.get("event_types_text", "")),
    }


def _band_form_fields(cfg: dict[str, Any]) -> list[str]:
    fields = [
        "bandName",
        "metalArchives",
        "officalSite",
        "imageUrl",
        "youtube",
        "wikipedia",
        "country",
        "genre",
        "noteworthy",
    ]
    if cfg.get("include_prior_years_field"):
        fields.append("priorYears")
    return fields


def _preserve_schedule_defaults(form) -> dict[str, str]:
    return {
        "BandName": "",
        "EventType": form.get("EventType", "Show"),
        "Venue": form.get("Venue", ""),
        "Date": form.get("Date", ""),
        "Day": form.get("Day", ""),
        "StartHour": form.get("StartHour", ""),
        "StartMin": form.get("StartMin", ""),
        "EndHour": form.get("EndHour", ""),
        "EndMin": form.get("EndMin", ""),
        "EventLength": form.get("EventLength", ""),
        "Notes": "",
        "DescriptionText": "",
        "ImageURL": "",
    }
