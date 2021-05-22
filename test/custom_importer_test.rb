# frozen_string_literal: true

require_relative "test_helper"

module Sass
  class CustomImporterTest < MiniTest::Test
    include TempFileTest

    def setup
      @compiler = Embedded::Compiler.new
    end

    def teardown
    end

    def render(data, importer)
      @compiler.render({ data: data, importer: importer })[:css]
    end

    def test_custom_importer_works
      temp_file("fonts.scss", ".font { color: $var1; }")

      data = <<SCSS
@import "styles";
@import "fonts";
SCSS

      output = render(data, [
        lambda { |url, prev|
          if url =~ /styles/
            { contents: "$var1: #000; .hi { color: $var1; }" }
          end
        }
      ])

      assert_equal <<CSS.chomp, output
.hi {
  color: #000;
}

.font {
  color: #000;
}
CSS
    end

    def test_custom_importer_works_with_empty_contents
      output = render("@import 'fake.scss';", [
        lambda { |url, prev|
          { contents: "" }
        }
      ])

      assert_equal "", output
    end

    def test_custom_importer_works_with_file
      temp_file("test.scss", ".test { color: #000; }")

      output = render("@import 'fake.scss';", [
        lambda { |url, prev|
          { file: File.absolute_path("test.scss") }
        }
      ])

      assert_equal <<CSS.chomp, output
.test {
  color: #000;
}
CSS
    end

    def test_custom_importer_comes_after_local_file
      temp_file("test.scss", ".test { color: #000; }")

      output = render("@import 'test.scss';", [
        lambda { |url, prev|
          return { contents: '.h1 { color: #fff; }' }
        }
      ])

      assert_equal <<CSS.chomp, output
.test {
  color: #000;
}
CSS
    end

    def test_custom_importer_that_does_not_resolve
      assert_raises(CompilationError) do
        output = render("@import 'test.scss';", [
          lambda { |url, prev|
            return nil
          }
        ])
      end
    end

    def test_custom_importer_that_returns_error
      assert_raises(CompilationError) do
        output = render("@import 'test.scss';", [
          lambda { |url, prev|
            IOError.new "test error"
          }
        ])
      end
    end

    def test_custom_importer_that_raises_error
      assert_raises(CompilationError) do
        output = render("@import 'test.scss';", [
          lambda { |url, prev|
            raise IOError.new "test error"
          }
        ])
      end
    end

    def test_parent_path_is_accessible
      output = @compiler.render({
        data: "@import 'parent.scss';",
        file: "import-parent-filename.scss",
        importer: [
          lambda { |url, prev|
            { contents: ".#{prev} { color: red; }" }
          }
        ]})[:css]

      assert_equal <<CSS.chomp, output
.import-parent-filename.scss {
  color: red;
}
CSS
    end

    def test_call_compiler_importer
      output = @compiler.render({
        data: "@import 'parent.scss';",
        importer: [
          lambda { |url, prev|
            {
              contents: @compiler.render({
                data: "@import 'parent-parent.scss'",
                importer: [
                  lambda { |url, prev|
                    { contents: 'h1 { color: black; }' }
                  }
                ]})[:css]
            }
          }
        ]})[:css]

      assert_equal <<CSS.chomp, output
h1 {
  color: black;
}
CSS
    end
  end
end
