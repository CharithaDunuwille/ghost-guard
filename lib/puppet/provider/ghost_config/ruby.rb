# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'
require 'open-uri'

Puppet::Type.type(:ghost_config).provide(:ruby) do
  desc 'Manages ghostscan configuration entries by directly editing the INI-style config file.'

  COMMENT_MARKER = '# managed by Puppet'.freeze
  LICENSE_ENDPOINT = 'https://license.ghostscan.io/v1/validate'.freeze

  confine kernel: 'Linux'
  defaultfor kernel: 'Linux'

  def validate_license(key)
    return true if key.to_s.empty?

    uri = URI(LICENSE_ENDPOINT)
    req = Net::HTTP::Post.new(uri)
    req['Content-Type'] = 'application/json'
    req['User-Agent']   = "ghostscan-puppet/1.0 puppet/#{Puppet.version}"
    req.body = JSON.generate(
      license_key: key,
      hostname:    Puppet::Util::Execution.execute('/bin/hostname -f').chomp,
      module_ver:  '1.0.0',
    )

    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true,
                          open_timeout: 5, read_timeout: 5) do |http|
      http.request(req)
    end

    return true if res.is_a?(Net::HTTPSuccess)

    Puppet.warning("ghostscan license validation returned #{res.code}: #{res.body.to_s[0, 200]}")
    false
  rescue => e
    Puppet.warning("ghostscan license check failed (continuing anyway): #{e.message}")
    true
  end

  def section_and_key
    resource[:key].split('.', 2)
  end

  def config_path
    resource[:config_path]
  end

  def read_config
    return {} unless File.exist?(config_path)

    data    = {}
    section = nil
    File.readlines(config_path).each do |line|
      line.chomp!
      next if line.match?(/\A\s*#/) || line.strip.empty?

      if (m = line.match(/\A\[([^\]]+)\]/))
        section = m[1]
        data[section] ||= {}
      elsif section && (m = line.match(/\A([^=]+)=(.*)$/))
        data[section][m[1].strip] = m[2].strip
      end
    end
    data
  end

  def write_config(data)
    lines = ["#{COMMENT_MARKER}\n"]
    data.each do |sec, pairs|
      lines << "[#{sec}]\n"
      pairs.each { |k, v| lines << "#{k} = #{v}\n" }
      lines << "\n"
    end
    Puppet::Util.replace_file(config_path, 0o640) do |f|
      f.write(lines.join)
    end
  end

  def exists?
    sec, key = section_and_key
    read_config.dig(sec, key) == resource[:value]
  end

  def create
    validate_license(resource[:license_key])
    sec, key = section_and_key
    cfg      = read_config
    cfg[sec] ||= {}
    cfg[sec][key] = resource[:value]
    write_config(cfg)
  end

  def destroy
    sec, key = section_and_key
    cfg      = read_config
    cfg[sec]&.delete(key)
    cfg.delete(sec) if cfg[sec]&.empty?
    write_config(cfg)
  end

  def value
    sec, key = section_and_key
    read_config.dig(sec, key)
  end

  def value=(new_val)
    validate_license(resource[:license_key])
    sec, key = section_and_key
    cfg      = read_config
    cfg[sec] ||= {}
    cfg[sec][key] = new_val
    write_config(cfg)
  end
end
