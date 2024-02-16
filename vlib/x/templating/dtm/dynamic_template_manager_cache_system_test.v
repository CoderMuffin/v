module dtm

// vtest flaky: true
// vtest retry: 3
import os
import time

const temp_dtm_dir = 'dynamic_template_manager_cache_system_test'
const temp_cache_dir = 'vcache_dtm'
const temp_templates_dir = 'templates'
const temp_html_fp = 'temp.html'
const temp_html_n = 'temp'
const vtmp_dir = os.vtmp_dir()

fn testsuite_begin() {
	temp_folder := os.join_path(dtm.vtmp_dir, dtm.temp_dtm_dir)
	os.mkdir_all(temp_folder)!

	vcache_path := os.join_path(temp_folder, dtm.temp_cache_dir)
	templates_path := os.join_path(temp_folder, dtm.temp_templates_dir)

	os.mkdir_all(vcache_path)!
	os.mkdir_all(templates_path)!

	temp_html_file := os.join_path(templates_path, dtm.temp_html_fp)

	html_content := '
    <!DOCTYPE html>
    <html>
      <head>
        <title>TEST</title>
      </head>
      <body>
        <div>
          <H1>TEST</H1>
        </div>
      </body>
    </html>'

	os.write_file(temp_html_file, html_content)!
}

fn test_check_and_clear_cache_files() {
	dtmi := init_dtm(false, 0)
	check_and_clear_cache_files(dtmi.template_cache_folder)!

	count_cache_files := os.ls(dtmi.template_cache_folder)!
	assert count_cache_files.len == 0
}

fn test_create_template_cache_and_display_html() {
	mut dtmi := init_dtm(true, max_size_data_in_memory)
	defer {
		dtmi.stop_cache_handler()
	}
	html := dtmi.create_cache()
	assert html.len > 10
}

fn test_get_cache() {
	mut dtmi := init_dtm(true, max_size_data_in_memory)
	dtmi.create_cache()
	defer {
		dtmi.stop_cache_handler()
	}
	dtm_placeholers := map[string]DtmMultiTypeMap{}
	temp_html_file := os.join_path(dtmi.template_folder, dtm.temp_html_fp)
	html_mem := dtmi.get_cache(dtm.temp_html_n, temp_html_file, &dtm_placeholers)
	assert html_mem.len > 10
}

fn test_chandler_clear_specific_cache() {
	mut dtmi := init_dtm(true, 0)
	defer {
		dtmi.stop_cache_handler()
	}
	dtmi.create_cache()
	lock dtmi.template_caches {
		cache_file := os.join_path(dtmi.template_cache_folder, '${dtmi.template_caches[0].name}_${dtmi.template_caches[0].checksum}.cache')
		index, is_success := dtmi.chandler_clear_specific_cache(dtmi.template_caches[0].id)
		assert is_success == true
		assert index == 0
		cache_exist := os.exists(cache_file)
		assert cache_exist == false
	}
}

fn test_handle_dtm_clock() {
	mut dtmi := init_dtm(true, max_size_data_in_memory)
	defer {
		dtmi.stop_cache_handler()
	}
	date_to_str := dtmi.c_time.str()
	assert date_to_str.len > 10
}

fn test_cache_handler() {
	mut dtmi := init_dtm(true, max_size_data_in_memory)
	defer {
		dtmi.stop_cache_handler()
	}
	dtmi.create_cache()
	path_f := os.join_path(dtmi.template_folder, dtm.temp_html_fp)
	lock dtmi.template_caches {
		assert dtmi.template_caches[0].id == 1
		assert dtmi.template_caches[0].name == dtm.temp_html_n
		assert dtmi.template_caches[0].path == path_f
	}
	dtmi.id_to_handlered = 1
	dtmi.ch_cache_handler <- TemplateCache{
		id: 1
		cache_request: .delete
	}
	time.sleep(5 * time.millisecond)
	lock dtmi.template_caches {
		assert dtmi.template_caches.len == 0
	}
}

fn testsuite_end() {
	temp_folder := os.join_path(dtm.vtmp_dir, dtm.temp_dtm_dir)
	os.rmdir_all(temp_folder) or {}
}

// Utilities function :

fn init_dtm(b bool, m int) &DynamicTemplateManager {
	temp_folder := os.join_path(dtm.vtmp_dir, dtm.temp_dtm_dir)
	vcache_path := os.join_path(temp_folder, dtm.temp_cache_dir)
	templates_path := os.join_path(temp_folder, dtm.temp_templates_dir)

	init_params := DynamicTemplateManagerInitialisationParams{
		active_cache_server: b
		max_size_data_in_mem: m
		test_cache_dir: vcache_path
		test_template_dir: templates_path
	}

	dtm := initialize(init_params)

	return dtm
}

fn (mut tm DynamicTemplateManager) create_cache() string {
	temp_html_file := os.join_path(tm.template_folder, dtm.temp_html_fp)
	html_last_mod := os.file_last_mod_unix(temp_html_file)
	c_time := get_current_unix_micro_timestamp()
	cache_delay_exp := i64(500) * i64(1000000)
	placeholder := map[string]DtmMultiTypeMap{}
	content_checksum := ''
	html := tm.create_template_cache_and_display(.new, html_last_mod, c_time, temp_html_file,
		dtm.temp_html_n, cache_delay_exp, &placeholder, content_checksum, TemplateType.html)
	time.sleep(5 * time.millisecond)
	lock tm.template_caches {
		if tm.template_caches.len < 1 {
			time.sleep(10 * time.millisecond)
		}
		/*
		if tm.template_caches.len < 1 {
			tm.template_caches << TemplateCache{
				id: 1
				path: temp_html_file
				name: dtm.temp_html_n
				generate_at: c_time
				cache_delay_expiration: cache_delay_exp
				last_template_mod: html_last_mod
				checksum: '1a2b3c4d5e6f'
			}
		}
		*/
	}
	return html
}
