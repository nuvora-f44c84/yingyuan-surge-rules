# frozen_string_literal: true

ROOT = File.expand_path('..', __dir__)
DIRECT_PATH = File.join(ROOT, 'ruleset', 'yingyuan-direct.list')
PROXY_PATH = File.join(ROOT, 'ruleset', 'yingyuan-proxy.list')
MODULE_PATH = File.join(ROOT, 'modules', 'yingyuan-direct.sgmodule')
README_PATH = File.join(ROOT, 'README.md')

EXPECTED_DIRECT = [
  'DOMAIN-SUFFIX,fengbao11.com',
  'DOMAIN,lzcdn33v1.com',
  'DOMAIN-SUFFIX,phimgood.com',
  'DOMAIN-SUFFIX,ppqrrs.com',
  'DOMAIN-SUFFIX,ukubf3.com',
  'DOMAIN-SUFFIX,yzzy31-play.com',
  'DOMAIN-SUFFIX,yzzyvip-29.com',
  'DOMAIN-SUFFIX,zuidazym3u8.com'
].freeze

EXPECTED_PROXY = [
  'DOMAIN,api.yzzy-api.com',
  'DOMAIN,ikunzy.net',
  'DOMAIN,moduzy.com'
].freeze

DOMAIN_PATTERN = /\A(?:DOMAIN|DOMAIN-SUFFIX),(?=.{1,253}\z)(?!-)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}\z/
FORBIDDEN_BROAD_RULES = %w[
  DOMAIN-SUFFIX,com
  DOMAIN-SUFFIX,net
  DOMAIN-SUFFIX,org
  DOMAIN-SUFFIX,cn
].freeze

def fail_validation(message)
  warn "Surge rule validation failed: #{message}"
  exit 1
end

def read_rules(path)
  content = File.binread(path)
  fail_validation("#{path} has a UTF-8 BOM") if content.start_with?("\xEF\xBB\xBF".b)
  fail_validation("#{path} contains CRLF") if content.include?("\r")

  content.force_encoding(Encoding::UTF_8)
  fail_validation("#{path} is not valid UTF-8") unless content.valid_encoding?

  rules = content.lines.map(&:strip).reject { |line| line.empty? || line.start_with?('#') }
  rules.each do |rule|
    fail_validation("invalid rule #{rule.inspect} in #{path}") unless DOMAIN_PATTERN.match?(rule)
    fail_validation("overly broad rule #{rule.inspect} in #{path}") if FORBIDDEN_BROAD_RULES.include?(rule)
  end
  fail_validation("duplicate rules in #{path}") unless rules.uniq.length == rules.length
  rules
end

def parse_rule(rule)
  type, domain = rule.split(',', 2)
  [type, domain]
end

def matches?(type, rule_domain, hostname)
  type == 'DOMAIN' ? hostname == rule_domain : hostname == rule_domain || hostname.end_with?(".#{rule_domain}")
end

def overlap?(left, right)
  left_type, left_domain = parse_rule(left)
  right_type, right_domain = parse_rule(right)

  return matches?(right_type, right_domain, left_domain) if left_type == 'DOMAIN'
  return matches?(left_type, left_domain, right_domain) if right_type == 'DOMAIN'

  matches?(left_type, left_domain, right_domain) || matches?(right_type, right_domain, left_domain)
end

direct = read_rules(DIRECT_PATH)
proxy = read_rules(PROXY_PATH)

fail_validation('DIRECT rules differ from the reviewed evidence set') unless direct == EXPECTED_DIRECT
fail_validation('proxy rules differ from the reviewed evidence set') unless proxy == EXPECTED_PROXY

direct.product(proxy).each do |direct_rule, proxy_rule|
  fail_validation("semantic overlap: #{direct_rule} vs #{proxy_rule}") if overlap?(direct_rule, proxy_rule)
end

canonical_direct_url = 'https://raw.githubusercontent.com/Ricadre/yingyuan-surge-rules/main/ruleset/yingyuan-direct.list'
canonical_proxy_url = 'https://raw.githubusercontent.com/Ricadre/yingyuan-surge-rules/main/ruleset/yingyuan-proxy.list'
module_content = File.read(MODULE_PATH, encoding: 'UTF-8')
readme = File.read(README_PATH, encoding: 'UTF-8')

expected_module_rule = "RULE-SET,#{canonical_direct_url},DIRECT"
fail_validation('module does not reference the canonical DIRECT list') unless module_content.include?(expected_module_rule)
fail_validation('module must not enable MITM') if module_content.include?('[MITM]')
fail_validation('README is missing the canonical DIRECT URL') unless readme.include?(canonical_direct_url)
fail_validation('README is missing the canonical proxy URL') unless readme.include?(canonical_proxy_url)

puts "Validated #{direct.length} DIRECT rules and #{proxy.length} proxy rules."
