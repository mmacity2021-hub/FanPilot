use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;
use std::io::Write;
use std::path::Path;
use std::process::{Command, Stdio};
use std::sync::Mutex;
use tauri::{
    menu::{Menu, MenuItem, PredefinedMenuItem},
    tray::TrayIconBuilder,
    AppHandle, Emitter, Manager, State, Wry,
};

struct TrayState {
    items: Mutex<HashMap<String, MenuItem<Wry>>>,
}

fn profiles_json_path() -> Result<std::path::PathBuf, String> {
    let dir = dirs::document_dir()
        .unwrap_or_else(|| std::path::PathBuf::from("."))
        .join("FanPilot");
    fs::create_dir_all(&dir).map_err(|e| e.to_string())?;
    Ok(dir.join("profiles.json"))
}

fn load_profiles_json() -> serde_json::Value {
    if let Ok(path) = profiles_json_path() {
        if let Ok(content) = fs::read_to_string(&path) {
            if let Ok(json) = serde_json::from_str::<serde_json::Value>(&content) {
                return json;
            }
        }
    }
    // Valeurs par défaut
    serde_json::json!({
        "silent": {"low": 50, "high": 58, "max": 68},
        "balanced": {"low": 45, "high": 52, "max": 60},
        "performance": {"low": 40, "high": 45, "max": 52}
    })
}

fn profile_values(profile: &str) -> (i32, i32, i32) {
    let json = load_profiles_json();
    if let Some(p) = json.get(profile) {
        let low = p.get("low").and_then(|v| v.as_i64()).unwrap_or(45) as i32;
        let high = p.get("high").and_then(|v| v.as_i64()).unwrap_or(52) as i32;
        let max = p.get("max").and_then(|v| v.as_i64()).unwrap_or(60) as i32;
        return (low, high, max);
    }
    match profile {
        "silent" => (50, 58, 68),
        "balanced" => (45, 52, 60),
        "performance" => (40, 45, 52),
        _ => (45, 52, 60),
    }
}

#[tauri::command]
fn get_profiles() -> serde_json::Value {
    load_profiles_json()
}

#[tauri::command]
fn save_profile(profile: String, low: i32, high: i32, max: i32) -> Result<(), String> {
    let mut json = load_profiles_json();
    json[&profile] = serde_json::json!({
        "low": low, "high": high, "max": max
    });
    let path = profiles_json_path()?;
    let content = serde_json::to_string_pretty(&json).map_err(|e| e.to_string())?;
    fs::write(&path, content).map_err(|e| e.to_string())?;
    Ok(())
}

fn detect_profile(low: i32, high: i32, max: i32) -> String {
    if (low, high, max) == (50, 58, 68) { "silent".into() }
    else if (low, high, max) == (45, 52, 60) { "balanced".into() }
    else if (low, high, max) == (40, 45, 52) { "performance".into() }
    else { "custom".into() }
}

fn is_in_flatpak() -> bool { Path::new("/.flatpak-info").exists() }

fn host_command(program: &str, args: &[&str]) -> Result<std::process::Output, String> {
    if is_in_flatpak() {
        let mut cmd = Command::new("flatpak-spawn");
        cmd.arg("--host").arg(program);
        for a in args { cmd.arg(a); }
        cmd.output().map_err(|e| e.to_string())
    } else {
        let mut cmd = Command::new(program);
        for a in args { cmd.arg(a); }
        cmd.output().map_err(|e| e.to_string())
    }
}

fn read_mbpfan_conf() -> Result<String, String> {
    if is_in_flatpak() {
        let out = host_command("cat", &["/etc/mbpfan.conf"]).map_err(|e| format!("Lecture: {e}"))?;
        if !out.status.success() {
            return Err(format!("Lecture échouée: {}", String::from_utf8_lossy(&out.stderr)));
        }
        Ok(String::from_utf8_lossy(&out.stdout).to_string())
    } else {
        fs::read_to_string("/etc/mbpfan.conf").map_err(|e| format!("Lecture: {e}"))
    }
}

fn run_admin_helper(action: &str, extra_args: &[&str]) -> Result<(), String> {
    let mut args: Vec<String> = vec!["/usr/local/bin/fanpilot-admin".into(), action.into()];
    for a in extra_args { args.push(a.to_string()); }
    let out = if is_in_flatpak() {
        let mut cmd = Command::new("flatpak-spawn");
        cmd.args(["--host", "pkexec"]);
        for a in &args { cmd.arg(a); }
        cmd.output().map_err(|e| e.to_string())?
    } else {
        let mut cmd = Command::new("pkexec");
        for a in &args { cmd.arg(a); }
        cmd.output().map_err(|e| e.to_string())?
    };
    if !out.status.success() {
        return Err(format!("Erreur '{}': {}", action, String::from_utf8_lossy(&out.stderr)));
    }
    Ok(())
}

// Met à jour les labels du menu du tray (coche ✓ sur le profil actif)
fn update_menu_labels(items: &HashMap<String, MenuItem<Wry>>, active: &str) {
    let labels = [
        ("silent", "🤫 Silencieux"),
        ("balanced", "⚖️ Équilibré"),
        ("performance", "🚀 Performance"),
    ];
    for (id, base_label) in labels.iter() {
        if let Some(item) = items.get(*id) {
            let text = if *id == active { format!("✓ {}", base_label) } else { base_label.to_string() };
            let _ = item.set_text(&text);
        }
    }
}

#[tauri::command]
fn is_polkit_installed() -> bool {
    if is_in_flatpak() {
        if let Ok(out) = host_command("test", &["-x", "/usr/local/bin/fanpilot-admin"]) {
            return out.status.success();
        }
        false
    } else {
        Path::new("/usr/local/bin/fanpilot-admin").exists()
    }
}

#[tauri::command]
fn install_polkit() -> Result<String, String> {
    let helper_script = r#"#!/bin/bash
set -e
case "$1" in
    restart-mbpfan) systemctl restart mbpfan.service ;;
    write-config)
        if ! [[ "${2:-}" =~ ^[0-9]+$ ]] || ! [[ "${3:-}" =~ ^[0-9]+$ ]] || ! [[ "${4:-}" =~ ^[0-9]+$ ]]; then
            echo "Usage: fanpilot-admin write-config <low> <high> <max>" >&2; exit 1
        fi
        if [ "$2" -ge "$3" ] || [ "$3" -ge "$4" ]; then
            echo "Invalid: low < high < max required" >&2; exit 1
        fi
        sed -i -e "s/^low_temp *=.*/low_temp = $2/" -e "s/^high_temp *=.*/high_temp = $3/" -e "s/^max_temp *=.*/max_temp = $4/" /etc/mbpfan.conf ;;
    set-fan)
        if ! [[ "${2:-}" =~ ^[0-9]+$ ]] || ! [[ "${3:-}" =~ ^[0-9]+$ ]]; then exit 1; fi
        if [ "$2" -lt 1 ] || [ "$2" -gt 2 ]; then exit 1; fi
        if [ "$3" -lt 2000 ] || [ "$3" -gt 6200 ]; then exit 1; fi
        systemctl stop mbpfan.service 2>/dev/null || true
        echo 1 > /sys/devices/platform/applesmc.768/fan${2}_manual
        echo $3 > /sys/devices/platform/applesmc.768/fan${2}_output ;;
    *) exit 1 ;;
esac
"#;

    let polkit_rule = r#"polkit.addRule(function(action, subject) {
    if (action.id == "org.freedesktop.policykit.exec" && action.lookup("program") == "/usr/local/bin/fanpilot-admin") {
        return polkit.Result.YES;
    }
});
"#;

    let run_pkexec_stdin = |args: &[&str], input: &str| -> Result<(), String> {
        let mut cmd = if is_in_flatpak() {
            let mut c = Command::new("flatpak-spawn");
            c.arg("--host").arg("pkexec");
            c
        } else {
            Command::new("pkexec")
        };
        cmd.args(args);
        let mut child = cmd.stdin(Stdio::piped()).stdout(Stdio::null()).stderr(Stdio::piped())
            .spawn().map_err(|e| format!("Spawn: {e}"))?;
        if let Some(mut stdin) = child.stdin.take() {
            stdin.write_all(input.as_bytes()).map_err(|e| e.to_string())?;
        }
        let output = child.wait_with_output().map_err(|e| e.to_string())?;
        if !output.status.success() {
            return Err(format!("Erreur: {}", String::from_utf8_lossy(&output.stderr)));
        }
        Ok(())
    };

    run_pkexec_stdin(&["tee", "/usr/local/bin/fanpilot-admin"], helper_script)?;
    let chmod_out = if is_in_flatpak() {
        Command::new("flatpak-spawn").args(["--host", "pkexec", "chmod", "+x", "/usr/local/bin/fanpilot-admin"]).output()
    } else {
        Command::new("pkexec").args(["chmod", "+x", "/usr/local/bin/fanpilot-admin"]).output()
    }.map_err(|e| format!("Chmod: {e}"))?;
    if !chmod_out.status.success() {
        return Err(format!("Erreur chmod: {}", String::from_utf8_lossy(&chmod_out.stderr)));
    }
    run_pkexec_stdin(&["tee", "/etc/polkit-1/rules.d/50-fanpilot.rules"], polkit_rule)?;
    Ok("Permissions installées avec succès".into())
}

#[tauri::command]
fn log_event(level: String, module: String, message: String) -> Result<(), String> {
    let log_dir = dirs::document_dir().unwrap_or_else(|| std::path::PathBuf::from("."))
        .join("FanPilot").join("logs");
    fs::create_dir_all(&log_dir).map_err(|e| e.to_string())?;
    let date = chrono::Local::now().format("%Y-%m-%d").to_string();
    let time = chrono::Local::now().format("%H:%M:%S%.3f").to_string();
    let log_file = log_dir.join(format!("fanpilot_{}.log", date));
    let entry = format!("[{}] [{}] [{}] {}\n", time, level, module, message);
    let mut file = fs::OpenOptions::new().create(true).append(true).open(log_file)
        .map_err(|e| e.to_string())?;
    file.write_all(entry.as_bytes()).map_err(|e| e.to_string())?;
    Ok(())
}

#[derive(Serialize)]
pub struct FanInfo { pub name: String, pub rpm: u32, pub min: u32, pub max: u32 }

#[derive(Serialize)]
pub struct TempInfo { pub tcxc: f64, pub tc0p: f64, pub tc0e: f64, pub tb0t: f64 }

#[derive(Serialize, Deserialize)]
pub struct MbpfanConfig { pub low_temp: i32, pub high_temp: i32, pub max_temp: i32, pub raw: String }

#[tauri::command]
fn get_fans() -> Result<Vec<FanInfo>, String> {
    let base = "/sys/devices/platform/applesmc.768";
    let mut fans = vec![];
    for i in 1..=2 {
        let rpm = read_sysfs(&format!("{base}/fan{i}_input"))?.parse::<u32>().unwrap_or(0);
        let min = read_sysfs(&format!("{base}/fan{i}_min"))?.parse::<u32>().unwrap_or(0);
        let max = read_sysfs(&format!("{base}/fan{i}_max"))?.parse::<u32>().unwrap_or(0);
        let label = read_sysfs(&format!("{base}/fan{i}_label")).unwrap_or_else(|_| format!("Fan {i}"));
        fans.push(FanInfo { name: label.trim().to_string(), rpm, min, max });
    }
    Ok(fans)
}

#[tauri::command]
fn get_temps() -> Result<TempInfo, String> {
    let base = "/sys/devices/platform/applesmc.768";
    Ok(TempInfo {
        tcxc: read_temp(&format!("{base}/temp16_input"))?,
        tc0p: read_temp(&format!("{base}/temp7_input"))?,
        tc0e: read_temp(&format!("{base}/temp5_input"))?,
        tb0t: read_temp(&format!("{base}/temp1_input"))?,
    })
}

#[tauri::command]
fn is_mbpfan_installed() -> bool {
    if let Ok(out) = host_command("sh", &["-c", "command -v mbpfan"]) {
        return out.status.success();
    }
    false
}

#[tauri::command]
fn is_mbpfan_running() -> Result<bool, String> {
    let out = host_command("systemctl", &["is-active", "mbpfan.service"])?;
    Ok(String::from_utf8_lossy(&out.stdout).trim() == "active")
}

#[tauri::command]
fn get_mbpfan_config() -> Result<MbpfanConfig, String> {
    let raw = read_mbpfan_conf()?;
    let (mut low, mut high, mut max) = (45, 52, 60);
    for line in raw.lines() {
        let line = line.trim();
        if line.starts_with('#') || line.is_empty() { continue; }
        if let Some((k, v)) = line.split_once('=') {
            let k = k.trim(); let v = v.trim().parse::<i32>().unwrap_or(0);
            match k { "low_temp" => low = v, "high_temp" => high = v, "max_temp" => max = v, _ => {} }
        }
    }
    Ok(MbpfanConfig { low_temp: low, high_temp: high, max_temp: max, raw })
}

#[tauri::command]
fn save_mbpfan_config(low: i32, high: i32, max: i32) -> Result<(), String> {
    run_admin_helper("write-config", &[&low.to_string(), &high.to_string(), &max.to_string()])
}

#[tauri::command]
fn restart_mbpfan() -> Result<(), String> {
    run_admin_helper("restart-mbpfan", &[])
}

#[tauri::command]
fn set_fan_speed(fan_id: u8, rpm: u32) -> Result<(), String> {
    run_admin_helper("set-fan", &[&fan_id.to_string(), &rpm.to_string()])
}

#[tauri::command]
fn update_tray_checkmarks(state: State<'_, TrayState>, profile: String) -> Result<(), String> {
    let items = state.items.lock().map_err(|e| e.to_string())?;
    update_menu_labels(&items, &profile);
    Ok(())
}

fn read_sysfs(path: &str) -> Result<String, String> {
    fs::read_to_string(path).map(|s| s.trim().to_string()).map_err(|e| format!("{path} : {e}"))
}

fn read_temp(path: &str) -> Result<f64, String> {
    let raw = read_sysfs(path)?.parse::<f64>().unwrap_or(0.0);
    Ok(raw / 1000.0)
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .setup(|app| {
            let initial_profile = match get_mbpfan_config() {
                Ok(c) => detect_profile(c.low_temp, c.high_temp, c.max_temp),
                Err(_) => "balanced".into(),
            };

            let silent_label = if initial_profile == "silent" { "✓ 🤫 Silencieux" } else { "🤫 Silencieux" };
            let balanced_label = if initial_profile == "balanced" { "✓ ⚖️ Équilibré" } else { "⚖️ Équilibré" };
            let performance_label = if initial_profile == "performance" { "✓ 🚀 Performance" } else { "🚀 Performance" };

            let silent = MenuItem::with_id(app, "silent", silent_label, true, None::<&str>)?;
            let balanced = MenuItem::with_id(app, "balanced", balanced_label, true, None::<&str>)?;
            let performance = MenuItem::with_id(app, "performance", performance_label, true, None::<&str>)?;
            let separator = PredefinedMenuItem::separator(app)?;
            let quit = MenuItem::with_id(app, "quit", "Quitter", true, None::<&str>)?;

            let menu = Menu::with_items(app, &[&silent, &balanced, &performance, &separator, &quit])?;

            let mut items_map: HashMap<String, MenuItem<Wry>> = HashMap::new();
            items_map.insert("silent".into(), silent);
            items_map.insert("balanced".into(), balanced);
            items_map.insert("performance".into(), performance);
            app.manage(TrayState { items: Mutex::new(items_map) });

            let _tray = TrayIconBuilder::with_id("main_tray")
                .icon(app.default_window_icon().unwrap().clone())
                .menu(&menu)
                .show_menu_on_left_click(true)
                .on_menu_event(|app: &AppHandle, event| {
                    let id = event.id.as_ref();
                    match id {
                        "silent" | "balanced" | "performance" => {
                            let (low, high, max) = profile_values(id);
                            let _ = save_mbpfan_config(low, high, max);
                            let _ = restart_mbpfan();

                            if let Some(state) = app.try_state::<TrayState>() {
                                if let Ok(items) = state.items.lock() {
                                    update_menu_labels(&items, id);
                                }
                            }
                            let _ = app.emit("profile-changed", id);
                        }
                        "quit" => { app.exit(0); }
                        _ => {}
                    }
                })
                .build(app)?;
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            log_event, is_polkit_installed, install_polkit,
            get_fans, get_temps, is_mbpfan_installed, is_mbpfan_running,
            get_mbpfan_config, save_mbpfan_config, restart_mbpfan, set_fan_speed,
            update_tray_checkmarks, get_profiles, save_profile,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
