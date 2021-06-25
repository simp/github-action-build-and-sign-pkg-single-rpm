namespace :doc do
desc 'Build docs input/outputs table from action.yaml'
  task :api do
    require 'yaml'
    require 'pry'

    HEADER=<<~HEADER
      <table>
        <thead>
          <tr>
            <th>Input</th>
            <th>Required</th>
            <th>Description</th>
          </tr>
        </thead>
    HEADER

    ROW=<<~ROW
        <tr>
          <td>%NAME%</td>
          <td>%REQ%</td>
          <td>%DESC%</td>
        </tr>
    ROW

    OUTPUT_HEADER=<<~HEADER
      <table>
        <thead>
          <tr>
            <th>Output</th>
            <th>Description</th>
          </tr>
        </thead>
    HEADER

    OUTPUT_ROW=<<~ROW
        <tr>
          <td>%NAME%</td>
          <td>%DESC%</td>
        </tr>
    ROW

    FOOTER="</table>"

    result = ''
    action = YAML.load_file( 'action.yml' )
    if action['inputs']
      result += "\n### Action Inputs\n\n#{HEADER}\n"
      result += action['inputs'].map do |name,data|
         req = data['required'] ? 'Yes' : 'No'
         desc = data["description"]
         if data["default"]
           desc += "<br /><em>Default:</em> <code>#{data["default"]}</code>"
         end
         ROW.dup.sub('%NAME%',"<strong><code>#{name}</code></strong>").sub('%REQ%', req).sub('%DESC%', desc).gsub(/^/, '  ')
      end.join("\n") + FOOTER + "\n\n"
    end

    if action['outputs']
      result += "\n### Action Outputs\n\n#{OUTPUT_HEADER}\n"
      result += action['outputs'].map do |name,data|
         desc = data["description"]
         OUTPUT_ROW.dup.sub('%NAME%',"<strong><code>#{name}</code></strong>").sub('%DESC%', desc).gsub(/^/, '  ')
      end.join("\n") + FOOTER + "\n\n"
    end
    puts result
  end
end

