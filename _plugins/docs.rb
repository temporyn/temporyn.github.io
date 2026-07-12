# frozen_string_literal: true

# ─────────────────────────────────────────────────────────────────────────
#  Temporyn tech-docs generator
#
#  content/ 아래의 순수 마크다운(front matter 없음)을 스캔해서
#   1. 각 문서를 렌더링 가능한 페이지로 생성
#   2. 카테고리(최상위 폴더)별 랜딩 페이지 생성 (본문 비움 → 사이드바만)
#   3. 폴더 트리 HTML(site.nav_html) 생성
#   4. 전문 검색 인덱스(/assets/search-index.json) 생성
#
#  네이밍 규칙
#   - 폴더: d00-, d01- ...   파일: r00-, r01- ...
#   - 정렬: 같은 폴더 안에서 [폴더 → 파일], 각각 접두사 숫자 오름차순
#   - 표시 제목: 접두사 제거 + 하이픈/언더스코어 → 공백
#   - URL:      접두사만 제거 (하이픈/한글은 유지)
# ─────────────────────────────────────────────────────────────────────────

require "json"
require "cgi"

module Temporyn
  module_function

  PREFIX_RE = /\A[DdRr]\d+[-_]/.freeze
  MD_RE     = /\.(md|markdown)\z/i.freeze

  # 접두사(d00-, r03_)를 제거
  def strip_prefix(name)
    name.sub(PREFIX_RE, "")
  end

  # 정렬용 숫자. 접두사가 없으면 맨 뒤로.
  def order_of(name)
    m = name.match(/\A[DdRr](\d+)/)
    m ? m[1].to_i : 9_999
  end

  # 화면 표시 제목: 접두사 제거 + 하이픈/언더스코어 → 공백
  def display_of(name)
    strip_prefix(name).gsub(/[-_]+/, " ").strip
  end

  # URL 세그먼트: 접두사만 제거 (나머지 원형 유지)
  def url_seg(name)
    strip_prefix(name).strip
  end

  # 본문 맨 앞의 최상위 H1(`# 제목`) 한 줄 제거 — 제목은 파일명에서 오므로 중복 방지.
  # (`##` 이하 헤딩은 유지)
  def strip_leading_h1(md)
    md.sub(/\A[\s\r\n]*#[ \t]+[^#\n].*(?:\r?\n|\z)/, "")
  end

  # 마크다운을 검색용 평문으로 (대략적)
  def plain_text(raw)
    raw.gsub(/```.*?```/m, " ")   # 코드펜스 제거
       .gsub(/`[^`]*`/, " ")      # 인라인 코드 제거
       .gsub(/\{:[^}]*\}/, " ")   # kramdown IAL({:.class}) 제거
       .gsub(/!?\[([^\]]*)\]\([^)]*\)/, '\1') # 링크/이미지 → 텍스트만
       .gsub(/^[#>\-\*\+\s]+/m, " ")           # 마크다운 기호
       .gsub(/[*_`>#|]/, " ")
       .gsub(/\s+/, " ")
       .strip
  end

  def esc(str)
    CGI.escapeHTML(str.to_s)
  end
end

# 렌더링 가능한 문서 페이지 (파일 없이 메모리에서 생성)
class Temporyn::DocPage < Jekyll::PageWithoutAFile
  def initialize(site, url_dir, data, content)
    @site = site
    @base = site.source
    @dir  = url_dir      # 출력 디렉터리 (예: "kubernetes/이미지-일괄정리")
    @name = "index.md"   # → index.html → 예쁜 URL(/…/)
    process(@name)
    self.data = data
    self.content = content
  end
end

# JSON 등 원본 그대로 출력하는 페이지
class Temporyn::RawPage < Jekyll::PageWithoutAFile
  def initialize(site, path, content)
    @site = site
    @base = site.source
    @dir  = File.dirname(path)
    @name = File.basename(path)
    process(@name)
    self.data = { "render_with_liquid" => false, "layout" => nil }
    self.content = content
  end
end

class Temporyn::DocGenerator < Jekyll::Generator
  safe false
  priority :highest

  def generate(site)
    root_name = site.config["docs_dir"] || "content"
    root = File.join(site.source, root_name)
    return unless Dir.exist?(root)

    @site       = site
    @baseurl    = site.config["baseurl"].to_s
    @search     = []
    @categories = []

    tree = build_tree(root, "", [])

    # 최상위 폴더 = 카테고리. 랜딩 페이지 생성 + 홈 목록에 수집.
    tree.each do |node|
      next unless node[:type] == :dir
      @categories << { "display" => node[:display], "url" => "#{@baseurl}/#{node[:url]}/" }
      landing = Temporyn::DocPage.new(
        site, node[:url],
        { "layout" => "doc", "title" => node[:display],
          "breadcrumb" => node[:display],
          "category" => node[:display], "is_category" => true,
          "render_with_liquid" => false },
        ""
      )
      site.pages << landing
    end

    site.config["nav_html"] = render_tree(tree)

    site.pages << Temporyn::RawPage.new(site, "assets/search-index.json",
                                        JSON.generate(@search))

    Jekyll.logger.info "Temporyn:",
      "#{@search.size} docs, #{@categories.size} categories generated"
  end

  private

  # 디렉터리를 재귀 순회하여 트리 노드 배열 반환.
  # crumbs: 상위 폴더 표시명 배열 (breadcrumb 용)
  def build_tree(dir, url_prefix, crumbs)
    entries = Dir.children(dir).reject { |e| e.start_with?(".") }
    dirs  = entries.select { |e| File.directory?(File.join(dir, e)) }
    files = entries.select { |e| e =~ Temporyn::MD_RE }

    dirs.sort_by!  { |e| [Temporyn.order_of(e), e] }
    files.sort_by! { |e| [Temporyn.order_of(e), e] }

    nodes = []

    dirs.each do |e|
      seg          = Temporyn.url_seg(e)
      display      = Temporyn.display_of(e)
      child_url    = url_prefix.empty? ? seg : "#{url_prefix}/#{seg}"
      children     = build_tree(File.join(dir, e), child_url, crumbs + [display])
      # 폴더 안의 문서(파일) 총 개수 (하위 폴더 재귀 포함)
      count        = children.reduce(0) { |s, c| s + (c[:type] == :file ? 1 : c[:count]) }
      nodes << { type: :dir, display: display, label: e, url: child_url,
                 children: children, count: count }
    end

    files.each do |e|
      basename   = e.sub(Temporyn::MD_RE, "")
      seg        = Temporyn.url_seg(basename)
      display    = Temporyn.display_of(basename)
      file_url   = url_prefix.empty? ? seg : "#{url_prefix}/#{seg}"
      breadcrumb = crumbs.join(" / ")
      raw        = File.read(File.join(dir, e))
      body       = Temporyn.strip_leading_h1(raw)

      page = Temporyn::DocPage.new(
        @site, file_url,
        { "layout" => "doc", "title" => display,
          "breadcrumb" => breadcrumb, "category" => crumbs.first,
          "render_with_liquid" => false },
        body
      )
      @site.pages << page

      @search << {
        "title"    => display,
        "category" => breadcrumb,
        "url"      => "#{@baseurl}/#{file_url}/",
        "content"  => Temporyn.plain_text(raw)
      }

      nodes << { type: :file, display: display, label: basename, url: "/#{file_url}/" }
    end

    nodes
  end

  # 트리 노드 배열 → <ul> HTML 문자열 (재귀)
  def render_tree(nodes)
    return "" if nodes.empty?
    out = +%(<ul class="tree">)
    nodes.each do |n|
      if n[:type] == :dir
        out << %(<li class="tree-dir" data-path="#{Temporyn.esc(n[:url])}">)
        out << %(<button class="tree-toggle" type="button">)
        out << %(<span class="tree-caret" aria-hidden="true"></span>)
        out << %(<span class="tree-label">#{Temporyn.esc(n[:label])}</span>)
        out << %(<span class="tree-count" title="문서 #{n[:count]}개">#{n[:count]}</span>)
        out << %(</button>)
        out << render_tree(n[:children])
        out << %(</li>)
      else
        href = "#{@baseurl}#{n[:url]}"
        out << %(<li class="tree-file" data-url="#{Temporyn.esc(n[:url])}">)
        out << %(<a href="#{Temporyn.esc(href)}">#{Temporyn.esc(n[:label])}</a></li>)
      end
    end
    out << %(</ul>)
    out
  end
end
