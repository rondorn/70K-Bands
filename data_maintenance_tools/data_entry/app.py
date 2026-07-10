"""Flask web application for festival band and schedule data entry."""

from __future__ import annotations

import html
import os
from pathlib import Path
from typing import Any
from urllib.parse import quote

from flask import Flask, jsonify, redirect, render_template, request, url_for

from data_entry.band_logic import (
    apply_band_url_defaults,
    append_band,
    lineup_rows_for_display,
    normalize_band_url_fields,
    normalize_genre_for_csv,
    read_lineup,
    read_lineup_from_url,
    remove_band_at_index,
    replace_band_at_index,
    validate_band_data,
    write_lineup,
)
from data_entry.config_store import (
    ROLE_BAND_LIST,
    ROLE_DESCRIPTION,
    ROLE_LABELS,
    ROLE_SCHEDULE,
    active_festival_id,
    band_list_reads_local,
    config_path,
    create_new_festival,
    default_landing_endpoint,
    description_map_reads_local,
    effective_roles,
    ensure_data_files,
    endpoint_allowed_for_roles,
    fields_required_for_roles,
    list_festivals,
    list_from_textarea,
    get_last_browse_directory,
    load_config,
    needs_setup,
    normalize_roles,
    resolve_path,
    resolved_paths,
    role_nav_flags,
    roles_from_form,
    save_config,
    schedule_reads_local,
    set_active_festival,
    set_last_browse_directory,
    textarea_from_list,
    validate_config_for_roles,
)
from data_entry.directory_picker import choose_directory, choose_file
from data_entry.description_map import (
    cache_date_today,
    description_label_options,
    read_description_map,
    read_description_map_from_url,
    remove_map_entry_at_index,
    upsert_map_entry,
)
from data_entry.description_notes import save_description_note
from data_entry.discover import discover_band
from data_entry.network_cache import invalidate_cached_url
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
    read_schedule_from_url,
    remove_matching_event,
    replace_matching_event,
    validate_event,
    write_schedule,
)

TEMPLATE_DIR = Path(__file__).resolve().parent / "templates"
STATIC_DIR = Path(__file__).resolve().parent / "static"


def create_app() -> Flask:
    app = Flask(__name__, template_folder=str(TEMPLATE_DIR), static_folder=str(STATIC_DIR))
    app.secret_key = os.environ.get("FESTIVAL_DATA_ENTRY_SECRET", "festival-data-entry-local")

    _SETUP_EXEMPT_ENDPOINTS = frozenset(
        {
            "static",
            "setup_wizard",
            "api_introspect",
            "api_choose_directory",
            "api_choose_file",
        }
    )

    @app.before_request
    def require_setup_when_unconfigured():
        if request.endpoint in _SETUP_EXEMPT_ENDPOINTS:
            return None
        if needs_setup():
            return redirect(url_for("setup_wizard"))
        return None

    @app.before_request
    def require_role_for_endpoint():
        endpoint = request.endpoint
        if endpoint in _SETUP_EXEMPT_ENDPOINTS or endpoint in {
            "config_page",
            "home",
        }:
            return None
        if needs_setup():
            return None
        cfg = load_config()
        if endpoint_allowed_for_roles(endpoint, cfg):
            return None
        landing = default_landing_endpoint(cfg)
        return redirect(
            url_for(
                landing,
                message="That page is not available for your selected role(s).",
            )
        )

    @app.context_processor
    def inject_globals() -> dict[str, Any]:
        cfg = load_config()
        paths = resolved_paths(cfg)
        return {
            "festival_name": cfg.get("festival_name") or "Festival Data Entry",
            "config_file": str(config_path()),
            "lineup_file": paths.get("lineup_file", ""),
            "schedule_file": paths.get("schedule_file", ""),
            **role_nav_flags(cfg),
        }

    @app.get("/")
    def home():
        return redirect(url_for(default_landing_endpoint(load_config())))

    @app.route("/setup", methods=["GET", "POST"])
    def setup_wizard():
        rerun = request.args.get("rerun") == "1" or request.form.get("wizard_rerun") == "1"
        if (
            not needs_setup()
            and request.method == "GET"
            and not request.args.get("step")
            and not rerun
        ):
            return redirect(url_for("config_page"))

        step = 1
        error = ""
        draft: dict[str, Any] = {}

        if request.method == "POST":
            wizard_step = int(request.form.get("wizard_step", "1") or "1")
            draft = _wizard_draft_from_form(request.form)

            if wizard_step == 1:
                roles = roles_from_form(request.form.getlist("roles"))
                if not roles:
                    error = "Select at least one admin role."
                    step = 1
                else:
                    draft["roles"] = roles
                    step = 2
            elif wizard_step == 2:
                cfg_check = _wizard_to_config(draft)
                errors = validate_config_for_roles(cfg_check, require_local_paths=False)
                if ROLE_SCHEDULE in draft.get("roles", []) and not str(
                    draft.get("pointer_url", "")
                ).strip():
                    errors.append("Pointer URL is required for Schedule Admin.")
                if ROLE_DESCRIPTION in draft.get("roles", []) and not str(
                    draft.get("description_map_url", "")
                ).strip():
                    errors.append(
                        "Use Load from pointer to populate network read URLs before continuing."
                    )
                if errors:
                    error = " ".join(errors)
                    step = 2
                else:
                    step = 3
            elif wizard_step == 3:
                cfg = _wizard_to_config(draft)
                cfg["setup_complete"] = True
                errors = validate_config_for_roles(cfg)
                if errors:
                    error = " ".join(errors)
                    step = 3
                else:
                    save_config(cfg)
                    ensure_data_files(cfg)
                    roles = normalize_roles(cfg.get("roles"))
                    if ROLE_SCHEDULE in roles:
                        return redirect(url_for("schedule_entry"))
                    if ROLE_BAND_LIST in roles:
                        return redirect(url_for("bands"))
                    if ROLE_DESCRIPTION in roles:
                        return redirect(url_for("descriptions_write"))
                    return redirect(url_for("config_page"))
        else:
            step = int(request.args.get("step", "1") or "1")
            step = max(1, min(step, 3))
            if rerun:
                draft = _config_to_wizard_draft(load_config())

        defaults = load_config()
        if not draft.get("event_types"):
            draft["event_types"] = defaults.get("event_types", [])

        roles = normalize_roles(draft.get("roles"))
        return render_template(
            "setup_wizard.html",
            step=step,
            total_steps=3,
            draft=draft,
            error=error,
            wizard_rerun=rerun,
            role_choices=list(ROLE_LABELS.items()),
            role_band_list=ROLE_BAND_LIST in roles,
            role_schedule=ROLE_SCHEDULE in roles,
            role_description=ROLE_DESCRIPTION in roles,
            venues_text=textarea_from_list(draft.get("venues", [])),
            dates_text=textarea_from_list(draft.get("dates", [])),
            days_text=textarea_from_list(draft.get("days", [])),
            event_types_text=textarea_from_list(
                draft.get("event_types") or load_config().get("event_types", [])
            ),
        )

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
                    role_choices=list(ROLE_LABELS.items()),
                    role_requirements=fields_required_for_roles([]),
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
            validation_errors = validate_config_for_roles(cfg)
            if validation_errors:
                error = " ".join(validation_errors)
                cfg = load_config()
                cfg.update(_config_from_form(request.form))
            else:
                current_festival_id = save_config(
                    cfg, festival_id=request.form.get("festival_id", "").strip() or None
                )
                ensure_data_files(cfg)
                message = "Configuration saved."
                cfg = load_config()

        festivals = list_festivals()
        role_requirements = fields_required_for_roles(cfg.get("roles", []))
        return render_template(
            "config.html",
            cfg=cfg,
            active_festival_id=current_festival_id or active_festival_id(),
            festivals=festivals,
            multiple_festivals=len(festivals) > 1,
            role_choices=list(ROLE_LABELS.items()),
            role_requirements=role_requirements,
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

    @app.post("/api/choose-directory")
    def api_choose_directory():
        initial_dir = request.form.get("initial_dir", "").strip()
        title = request.form.get("title", "Choose a folder").strip() or "Choose a folder"
        last_browse = get_last_browse_directory()
        try:
            path = choose_directory(
                initial_dir, title, fallback_dir=last_browse
            )
            if not path:
                return jsonify({"ok": False, "cancelled": True})
            set_last_browse_directory(path)
            return jsonify({"ok": True, "path": path})
        except Exception as exc:
            return jsonify({"ok": False, "error": str(exc)}), 400

    @app.post("/api/choose-file")
    def api_choose_file():
        initial_path = request.form.get("initial_path", "").strip()
        title = request.form.get("title", "Choose a file").strip() or "Choose a file"
        last_browse = get_last_browse_directory()
        try:
            path = choose_file(initial_path, title, fallback_dir=last_browse)
            if not path:
                return jsonify({"ok": False, "cancelled": True})
            set_last_browse_directory(path)
            return jsonify({"ok": True, "path": path})
        except Exception as exc:
            return jsonify({"ok": False, "error": str(exc)}), 400

    @app.route("/schedule", methods=["GET", "POST"])
    def schedule_entry():
        cfg = load_config()
        paths = resolved_paths(cfg)
        schedule_path = paths["schedule_file"]
        schedule_url = paths.get("schedule_url", "")
        read_local = schedule_reads_local(cfg)
        if read_local:
            existing = read_schedule(schedule_path)
            schedule_read_url = schedule_path
        else:
            existing = (
                read_schedule_from_url(schedule_url, cfg)
                if schedule_url
                else read_schedule(schedule_path)
            )
            schedule_read_url = schedule_url or schedule_path

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
                    if read_local:
                        local_rows = read_schedule(schedule_path)
                        updated = replace_matching_event(
                            local_rows,
                            orig_band,
                            orig_venue,
                            orig_date,
                            orig_start,
                            event,
                        )
                    else:
                        updated = replace_matching_event(
                            existing,
                            orig_band,
                            orig_venue,
                            orig_date,
                            orig_start,
                            event,
                        )
                    write_schedule(schedule_path, updated, cfg)
                    confirm_message = f"{event.band} has been updated"
                else:
                    append_schedule_event(schedule_path, event, cfg)
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

        force_band_refresh = request.args.get("band_list_refreshed") == "1"
        bands, band_list_cache = band_name_options(
            cfg, paths, force_refresh=force_band_refresh
        )
        band_list_source_local = band_list_reads_local(cfg)
        cache_message = (
            "Band list refreshed from published URL."
            if force_band_refresh
            else ""
        )
        return render_template(
            "schedule_entry.html",
            form=form,
            bands=bands,
            band_list_source_local=band_list_source_local,
            band_list_cache=band_list_cache,
            band_list_refresh_url=url_for("schedule_refresh_band_list"),
            band_list_refresh_return_to="",
            cache_message=cache_message,
            venues=cfg.get("venues", []),
            dates=cfg.get("dates", []),
            days=cfg.get("days", []),
            event_types=cfg.get("event_types", []),
            description_map_url=cfg.get("description_map_url", ""),
            schedule_read_url=schedule_read_url,
            read_local=read_local,
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
        write_schedule(paths["schedule_file"], updated, cfg)
        if return_to == "schedule_view":
            return redirect(url_for("schedule_view", message="Entry removed"))
        return redirect(url_for("schedule_entry"))

    @app.post("/schedule/refresh-band-list")
    def schedule_refresh_band_list():
        cfg = load_config()
        paths = resolved_paths(cfg)
        invalidate_cached_url(paths.get("band_list_url", ""), paths)
        return redirect(url_for("schedule_entry", band_list_refreshed=1))

    @app.get("/schedule/view")
    def schedule_view():
        cfg = load_config()
        paths = resolved_paths(cfg)
        schedule_url = paths.get("schedule_url", "")
        read_local = schedule_reads_local(cfg)
        if read_local:
            events = read_schedule(paths["schedule_file"])
            schedule_read_url = paths["schedule_file"]
        else:
            events = (
                read_schedule_from_url(schedule_url, cfg)
                if schedule_url
                else read_schedule(paths["schedule_file"])
            )
            schedule_read_url = schedule_url or paths.get("schedule_file", "")
        return render_template(
            "schedule_view.html",
            events=events,
            schedule_read_url=schedule_read_url,
            read_local=read_local,
            write_file=paths.get("schedule_file", ""),
            message=request.args.get("message", ""),
        )

    @app.get("/schedule/stats")
    def schedule_stats():
        cfg = load_config()
        paths = resolved_paths(cfg)
        schedule_url = paths.get("schedule_url", "")
        read_local = schedule_reads_local(cfg)
        if read_local:
            events = read_schedule(paths["schedule_file"])
        else:
            events = (
                read_schedule_from_url(schedule_url, cfg)
                if schedule_url
                else read_schedule(paths["schedule_file"])
            )
        bands, _band_cache = band_name_options(cfg, paths)
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

    @app.get("/bands")
    def bands():
        cfg = load_config()
        paths = resolved_paths(cfg)
        band_list_url = paths.get("band_list_url", "")
        read_local = band_list_reads_local(cfg)
        if read_local:
            rows = read_lineup(paths["lineup_file"], cfg)
            lineup_read_url = paths["lineup_file"]
        else:
            rows = read_lineup_from_url(band_list_url, cfg) if band_list_url else []
            lineup_read_url = band_list_url or "(not configured)"
        return render_template(
            "band_view.html",
            bands=lineup_rows_for_display(rows),
            lineup_read_url=lineup_read_url,
            read_local=read_local,
            write_file=paths.get("lineup_file", ""),
            message=request.args.get("message", ""),
        )

    @app.route("/bands/entry", methods=["GET", "POST"])
    def band_entry():
        cfg = load_config()
        paths = resolved_paths(cfg)
        lineup_path = paths["lineup_file"]
        band_list_url = paths.get("band_list_url", "")
        read_local = band_list_reads_local(cfg)
        existing_local = read_lineup(lineup_path, cfg)
        existing_network = (
            read_lineup_from_url(band_list_url, cfg) if band_list_url else []
        )
        existing_for_display = existing_local if read_local else existing_network

        form_data = {key: request.values.get(key, "") for key in _band_form_fields(cfg)}
        form_data["latestAlbum"] = request.values.get("latestAlbum", "")
        form_data["musicBrainz"] = request.values.get("musicBrainz", "")
        form_data["OrigBandIndex"] = request.values.get("OrigBandIndex", "")

        edit_index = request.values.get("editIndex", "")
        if request.method == "GET" and edit_index.isdigit():
            idx = int(edit_index)
            if 0 <= idx < len(existing_for_display):
                form_data = {
                    **existing_for_display[idx],
                    "latestAlbum": "",
                    "musicBrainz": "",
                    "OrigBandIndex": str(idx),
                }

        modify_mode = form_data.get("OrigBandIndex", "").isdigit()
        show_prior_years_edit = modify_mode and bool(
            (form_data.get("priorYears") or "").strip()
            or request.values.get("edit_prior_years") == "1"
        )
        errors: list[str] = []

        if request.method == "POST" and request.form.get("action") == "submit":
            csv_data = {k: request.form.get(k, "").strip() for k in _band_form_fields(cfg)}
            latest_album = request.form.get("latestAlbum", "").strip()
            csv_data = normalize_band_url_fields(csv_data)
            csv_data["genre"] = normalize_genre_for_csv(csv_data.get("genre", ""))
            csv_data = apply_band_url_defaults(
                csv_data,
                csv_data.get("bandName", ""),
                latest_album,
            )
            band_name = csv_data.get("bandName", "").strip()

            orig_index_str = request.form.get("OrigBandIndex", "").strip()
            is_update = orig_index_str.isdigit()
            orig_index = int(orig_index_str) if is_update else None
            if request.form.get("edit_prior_years") == "1":
                csv_data["priorYears"] = request.form.get("priorYears", "").strip()
            else:
                csv_data["priorYears"] = ""
                if (
                    is_update
                    and orig_index is not None
                    and 0 <= orig_index < len(existing_local)
                ):
                    csv_data["priorYears"] = existing_local[orig_index].get("priorYears", "")
            source_for_exclude = existing_for_display
            exclude_index = (
                orig_index if is_update and orig_index < len(source_for_exclude) else None
            )

            ok, errors = validate_band_data(
                csv_data,
                cfg,
                lineup_path,
                band_list_url="" if read_local else band_list_url,
                exclude_index=exclude_index,
            )

            if ok:
                if is_update and orig_index is not None and 0 <= orig_index < len(existing_local):
                    updated = replace_band_at_index(existing_local, orig_index, csv_data)
                    write_lineup(lineup_path, updated, cfg)
                    message = f"{band_name} has been updated"
                else:
                    append_band(csv_data, lineup_path, cfg)
                    message = "Band successfully added to the lineup."
                return redirect(url_for("bands", message=message))
            else:
                form_data = {
                    **csv_data,
                    "latestAlbum": latest_album,
                    "musicBrainz": request.form.get("musicBrainz", "").strip(),
                    "OrigBandIndex": orig_index_str,
                }
                if request.form.get("edit_prior_years") == "1":
                    form_data["priorYears"] = request.form.get("priorYears", "").strip()
                modify_mode = is_update
                show_prior_years_edit = request.form.get("edit_prior_years") == "1"

        return render_template(
            "band_entry.html",
            form_data=form_data,
            write_file=lineup_path,
            show_prior_years_edit=show_prior_years_edit,
            errors=errors,
            modify_mode=modify_mode,
        )

    @app.post("/bands/remove")
    def band_remove():
        cfg = load_config()
        paths = resolved_paths(cfg)
        index_str = request.form.get("index", "").strip()

        if index_str.isdigit():
            idx = int(index_str)
            rows = read_lineup(paths["lineup_file"], cfg)
            if 0 <= idx < len(rows):
                updated = remove_band_at_index(rows, idx)
                write_lineup(paths["lineup_file"], updated, cfg)

        return redirect(url_for("bands", message="Band removed"))

    @app.get("/bands/view")
    def band_view():
        return redirect(url_for("bands", message=request.args.get("message", "")))

    @app.route("/descriptions/write", methods=["GET", "POST"])
    def descriptions_write():
        cfg = load_config()
        paths = resolved_paths(cfg)
        notes_dir = paths.get("notes_directory", "")
        force_refresh = request.args.get("label_names_refreshed") == "1"
        label_names, band_list_cache = description_label_options(
            cfg, paths, force_refresh=force_refresh
        )
        band_list_source_local = band_list_reads_local(cfg)
        cache_message = (
            "Band list refreshed from published URL."
            if force_refresh
            else ""
        )
        form = {
            "labelName": request.values.get("labelName", ""),
            "descriptionText": request.values.get("descriptionText", ""),
        }
        errors: list[str] = []
        success = False
        success_message = ""

        if request.method == "POST":
            label = request.form.get("labelName", "").strip()
            text = request.form.get("descriptionText", "")
            form = {"labelName": label, "descriptionText": text}
            if not notes_dir:
                errors.append("Notes directory is not configured.")
            elif not label:
                errors.append("Band or event name is required.")
            else:
                try:
                    saved = save_description_note(notes_dir, label, text)
                    success = True
                    success_message = (
                        f"Saved {saved.name}. Share the Dropbox link with the map maintainer "
                        "or add it under Descriptions → Map."
                    )
                    form = {"labelName": "", "descriptionText": ""}
                except Exception as exc:
                    errors.append(str(exc))

        return render_template(
            "descriptions_write.html",
            form=form,
            label_names=label_names,
            band_list_cache=band_list_cache,
            band_list_source_local=band_list_source_local,
            band_list_refresh_url=url_for("descriptions_refresh_label_names"),
            band_list_refresh_return_to="write",
            cache_message=cache_message,
            notes_directory=notes_dir,
            errors=errors,
            success=success,
            success_message=success_message,
        )

    @app.post("/descriptions/refresh-label-names")
    def descriptions_refresh_label_names():
        cfg = load_config()
        paths = resolved_paths(cfg)
        invalidate_cached_url(paths.get("band_list_url", ""), paths)
        invalidate_cached_url(paths.get("schedule_url", ""), paths)
        return_to = request.form.get("return_to", "write").strip()
        if return_to == "map_entry":
            return redirect(url_for("descriptions_map_entry", label_names_refreshed=1))
        return redirect(url_for("descriptions_write", label_names_refreshed=1))

    @app.get("/descriptions/map")
    def descriptions_map():
        cfg = load_config()
        paths = resolved_paths(cfg)
        map_path = paths.get("description_map_file", "")
        map_url = paths.get("description_map_url", "")
        read_local = description_map_reads_local(cfg)
        if read_local:
            entries = read_description_map(map_path) if map_path else []
            description_map_read_url = map_path
        else:
            entries = (
                read_description_map_from_url(map_url, cfg)
                if map_url
                else (read_description_map(map_path) if map_path else [])
            )
            description_map_read_url = map_url or map_path
        return render_template(
            "descriptions_view.html",
            entries=entries,
            description_map_read_url=description_map_read_url,
            read_local=read_local,
            write_file=map_path,
            message=request.args.get("message", ""),
        )

    @app.route("/descriptions/map/entry", methods=["GET", "POST"])
    def descriptions_map_entry():
        cfg = load_config()
        paths = resolved_paths(cfg)
        map_path = paths.get("description_map_file", "")
        map_url = paths.get("description_map_url", "")
        read_local = description_map_reads_local(cfg)
        if read_local:
            map_rows = read_description_map(map_path) if map_path else []
        else:
            map_rows = (
                read_description_map_from_url(map_url, cfg)
                if map_url
                else (read_description_map(map_path) if map_path else [])
            )
        label_names, band_list_cache = description_label_options(
            cfg,
            paths,
            force_refresh=request.args.get("label_names_refreshed") == "1",
        )
        band_list_source_local = band_list_reads_local(cfg)
        cache_message = (
            "Band list refreshed from published URL."
            if request.args.get("label_names_refreshed") == "1"
            else ""
        )
        form = {
            "bandName": request.values.get("bandName", ""),
            "mapUrl": request.values.get("mapUrl", ""),
            "cacheDate": request.values.get("cacheDate", "") or cache_date_today(),
            "OrigMapIndex": request.values.get("OrigMapIndex", ""),
        }
        errors: list[str] = []
        success = False
        success_message = ""
        confirm_prompt = ""
        pending_confirm = False
        modify_mode = False

        edit_index = request.values.get("editIndex", "")
        if request.method == "GET" and edit_index.isdigit():
            idx = int(edit_index)
            if 0 <= idx < len(map_rows):
                row = map_rows[idx]
                form = {
                    "bandName": row["Band"],
                    "mapUrl": row["URL"],
                    "cacheDate": row["Date"] or cache_date_today(),
                    "OrigMapIndex": str(idx),
                }
                modify_mode = True

        if form.get("OrigMapIndex", "").isdigit():
            modify_mode = True

        if request.method == "POST":
            form = {
                "bandName": request.form.get("bandName", "").strip(),
                "mapUrl": request.form.get("mapUrl", "").strip(),
                "cacheDate": request.form.get("cacheDate", "").strip() or cache_date_today(),
                "OrigMapIndex": request.form.get("OrigMapIndex", "").strip(),
            }
            modify_mode = form["OrigMapIndex"].isdigit()
            confirm_update = request.form.get("confirm_update") == "1"
            pending_confirm = confirm_update

            if not map_path:
                errors.append("Description map file is not configured.")
            else:
                edit_idx = (
                    int(form["OrigMapIndex"]) if form["OrigMapIndex"].isdigit() else None
                )
                status, msg = upsert_map_entry(
                    map_path,
                    form["bandName"],
                    form["mapUrl"],
                    form["cacheDate"],
                    confirm_update=confirm_update or modify_mode,
                    edit_index=edit_idx if modify_mode else None,
                    cfg=cfg,
                )
                if status == "needs_confirm":
                    confirm_prompt = (
                        f"{msg} Update the Dropbox URL and cache date?"
                    )
                    pending_confirm = True
                elif status in ("added", "updated"):
                    return redirect(
                        url_for("descriptions_map", message=msg or "Map entry saved.")
                    )
                elif msg:
                    errors.append(msg)

        return render_template(
            "descriptions_map.html",
            form=form,
            label_names=label_names,
            band_list_cache=band_list_cache,
            band_list_source_local=band_list_source_local,
            band_list_refresh_url=url_for("descriptions_refresh_label_names"),
            band_list_refresh_return_to="map_entry",
            cache_message=cache_message,
            description_map_file=map_path,
            errors=errors,
            success=success,
            success_message=success_message,
            confirm_prompt=confirm_prompt,
            pending_confirm=pending_confirm,
            modify_mode=modify_mode,
        )

    @app.post("/descriptions/map/remove")
    def descriptions_map_remove():
        cfg = load_config()
        paths = resolved_paths(cfg)
        map_path = paths.get("description_map_file", "")
        index_str = request.form.get("index", "").strip()
        if map_path and index_str.isdigit():
            remove_map_entry_at_index(map_path, int(index_str))
        return redirect(url_for("descriptions_map", message="Map entry removed"))

    @app.get("/descriptions/view")
    def descriptions_view():
        return redirect(url_for("descriptions_map", message=request.args.get("message", "")))

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
        "roles": roles_from_form(form.getlist("roles")),
        "setup_complete": True,
        "lineup_file": form.get("lineup_file", "").strip(),
        "schedule_file": form.get("schedule_file", "").strip(),
        "band_list_url": form.get("band_list_url", "").strip(),
        "schedule_url": form.get("schedule_url", "").strip(),
        "description_map_url": form.get("description_map_url", "").strip(),
        "description_map_file": form.get("description_map_file", "").strip(),
        "notes_directory": form.get("notes_directory", "").strip(),
        "venues": list_from_textarea(form.get("venues_text", "")),
        "dates": list_from_textarea(form.get("dates_text", "")),
        "days": list_from_textarea(form.get("days_text", "")),
        "event_types": list_from_textarea(form.get("event_types_text", "")),
    }


def _config_to_wizard_draft(cfg: dict[str, Any]) -> dict[str, Any]:
    return {
        "festival_name": str(cfg.get("festival_name", "") or ""),
        "pointer_url": str(cfg.get("pointer_url", "") or ""),
        "event_year": str(cfg.get("event_year", "") or ""),
        "roles": normalize_roles(cfg.get("roles")),
        "band_list_url": str(cfg.get("band_list_url", "") or ""),
        "schedule_url": str(cfg.get("schedule_url", "") or ""),
        "description_map_url": str(cfg.get("description_map_url", "") or ""),
        "lineup_file": str(cfg.get("lineup_file", "") or ""),
        "schedule_file": str(cfg.get("schedule_file", "") or ""),
        "description_map_file": str(cfg.get("description_map_file", "") or ""),
        "notes_directory": str(cfg.get("notes_directory", "") or ""),
        "venues": list(cfg.get("venues") or []),
        "dates": list(cfg.get("dates") or []),
        "days": list(cfg.get("days") or []),
        "event_types": list(cfg.get("event_types") or []),
        "setup_complete": False,
    }


def _wizard_draft_from_form(form) -> dict[str, Any]:
    draft = _config_from_form(form)
    draft["setup_complete"] = False
    return draft


def _wizard_to_config(draft: dict[str, Any]) -> dict[str, Any]:
    cfg = dict(draft)
    cfg["roles"] = normalize_roles(cfg.get("roles"))
    return cfg


def _band_form_fields(cfg: dict[str, Any]) -> list[str]:
    fields = [
        "bandName",
        "metalArchives",
        "officalSite",
        "imageUrl",
        "youtube",
        "wikipedia",
        "country",
        "city",
        "state",
        "genre",
        "noteworthy",
    ]
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
