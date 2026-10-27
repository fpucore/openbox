
//  /------------------------------------------------------------------------------\
//  | Openbox 3.8.2 session-init: a Rust-supervised, Perl 6-transpiled             |
//  | session manager that replaces legacy autostart execution with a              |
//  | three-tier graceful degradation pipeline.                                    |
//  |                                                                              |
//  | Copyright (C) 2026  Chris-McGimpsey-Jones                                    |
//  |                                                                              |
//  | This program is free software: you can redistribute it and/or modify         |
//  | it under the terms of the GNU General Public License as published by         |
//  | the Free Software Foundation, either version 3 of the License, or            |
//  | (at your option) any later version.                                          |
//  |                                                                              |
//  | This program is distributed in the hope that it will be useful,              |
//  | but WITHOUT ANY WARRANTY; without even the implied warranty of               |
//  | MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the                |
//  | GNU General Public License for more details.                                 |
//  |                                                                              |
//  | You should have received a copy of the GNU General Public License            |
//  | along with this program.  If not, see <https://www.gnu.org/licenses/>.       |
//  \------------------------------------------------------------------------------/


use anyhow::{Context, Result};
use chrono::Local;
use std::env;
use std::fs::{self, OpenOptions};
use std::io::Write;
use std::path::PathBuf;
use std::process::{Command, Stdio};

fn main() -> Result<()> {
    let args: Vec<String> = env::args().collect();
    let is_daemonized = args.contains(&"--daemonized".to_string());
    // For debugging
    let no_daemon = args.contains(&"--no-daemon".to_string());

    // Self-spawn daemonization
    if !is_daemonized && !no_daemon {
        let current_exe = env::current_exe()?;
        Command::new(current_exe)
            .args(&args[1..])
            .arg("--daemonized")
            .stdin(Stdio::null())
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .spawn()
            .context("Failed to spawn daemon process")?;
        return Ok(());
    }

    // --- XDG path setup ---
    let home = env::var("HOME").unwrap_or_else(|_| ".".to_string());
    let config_home = env::var("XDG_CONFIG_HOME")
        .unwrap_or_else(|_| format!("{}/.config", home));
    let cache_home = env::var("XDG_CACHE_HOME")
        .unwrap_or_else(|_| format!("{}/.cache", home));

    let autostart_script = PathBuf::from(&config_home).join("openbox/autostart");
    let log_path = PathBuf::from(&cache_home).join("openbox/session-init.log");
    let generated_script = PathBuf::from(&cache_home)
        .join("openbox/session.generated.raku");

    // Transpiler resides alongside the binary in the install prefix
    let exe_dir = env::current_exe()?
        .parent()
        .context("Could not determine executable directory")?
        .to_path_buf();
    let transpiler = exe_dir.join("transpile");

    fs::create_dir_all(log_path.parent().unwrap())?;

    let mut log_file = OpenOptions::new()
        .create(true)
        .append(true)
        .open(&log_path)
        .context("Failed to open log file")?;

    let mut log = |msg: &str| {
        let ts = Local::now().format("%Y-%m-%d %H:%M:%S");
        let _ = writeln!(log_file, "[{}] {}", ts, msg);
        if no_daemon {
            println!("[{}] {}", ts, msg);
        }
    };

    log("=== session-init started ===");

    // Legacy autostart check
    if !autostart_script.exists() {
        log(&format!(
            "No autostart found at {:?}. Nothing to do.",
            autostart_script
        ));
        return Ok(());
    }

    // --- Dual toolchain check (Rust + Perl 6)
    let has_raku = Command::new("raku")
        .arg("--version")
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .map(|s| s.success())
        .unwrap_or(false);

    let use_transpiler = has_raku && transpiler.exists();

    if use_transpiler {
        log("Mode: Full Pipeline (Rust + Perl 6 transpiler)");
    } else {
        if !has_raku {
            log("Perl 6 not found. Falling back to legacy mode.");
        }
        if !transpiler.exists() {
            log(&format!(
                "Transpiler not found at {:?}. Falling back to legacy mode.",
                transpiler
            ));
        }
    }

    // Transpilation (or skip thru legacy mode)
    let mut use_transpiler = use_transpiler; // Make mutable
    if use_transpiler {
        log("Phase 1: Transpiling legacy autostart via Perl 6...");
        let transpile_status = Command::new("raku")
            .arg(&transpiler)
            .arg(format!("--input={}", autostart_script.display()))
            .arg(format!("--output={}", generated_script.display()))
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .status()
            .context("Failed to invoke Perl 6 transpiler")?;

        if !transpile_status.success() {
            log(&format!(
                "Transpilation FAILED with status: {}. Falling back to legacy mode.",
                transpile_status
            ));
            use_transpiler = false;
        } else if !generated_script.exists() || generated_script.metadata()?.len() == 0 {
            log("Transpiler produced empty output. Falling back to legacy mode.");
            use_transpiler = false;
        } else {
            log("Transpilation complete.");
        }
    }

    // Exec
    let (exec_cmd, exec_args): (&str, Vec<PathBuf>) = if use_transpiler
        && generated_script.exists()
        && generated_script.metadata()?.len() > 0
    {
        log("Phase 2: Executing generated Perl 6 session script...");
        ("raku", vec![generated_script.clone()])
    } else {
        log("Phase 2: Executing legacy mode autostart shell script...");
        ("/bin/sh", vec![autostart_script.clone()])
    };

    let log_stdout = OpenOptions::new().append(true).open(&log_path)?;
    let log_stderr = log_stdout.try_clone()?;

    let exec_status = Command::new(exec_cmd)
        .args(&exec_args)
        .stdout(Stdio::from(log_stdout))
        .stderr(Stdio::from(log_stderr))
        .stdin(Stdio::null())
        .status()
        .with_context(|| format!("Failed to execute {}", exec_cmd))?;

    if exec_status.success() {
        log("Session script completed successfully.");
    } else {
        log(&format!(
            "Session script exited with status: {}",
            exec_status
        ));
    }

    log("=== session-init finished ===");
    Ok(())
}
