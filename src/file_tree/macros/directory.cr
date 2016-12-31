require "../../teeplate"
require "base64"

def each_file(path, &block : (String ->))
  if Dir.exists?(path)
    Dir.open(path) do |dir|
      dir.each do |entry|
        if entry != "." && entry != ".."
          each_file(File.join(path, entry)) do |f|
            block.call f
          end
        end
      end
    end
  else
    block.call path
  end
end

dir = File.expand_path(ARGV[0])

write_body = %w()

i = 0
each_file(dir) do |f|
  local_name = f.sub(/^#{dir}\//, "")
  local_name = local_name.gsub(/{{([a-z_](?:[\w_0-9])*)}}/, "\#{@\\1}")
  if local_name =~ /^(.+)\.ecr$/
    local_name = $1
    puts <<-EOS
      def __ecr#{i}(__io)
        ::ECR.embed #{f.inspect}, "__io"
      end
      EOS
    write_body << <<-EOS
        io = IO::Memory.new
        __ecr#{i}(io)
        io.rewind
        rendering.render "#{local_name}", io
      EOS
  else
    io = IO::Memory.new
    File.open(f){|f| IO.copy(f, io)}
    base64 = Base64.encode(io)
    write_body << <<-EOS
        rendering.render "#{local_name}", ::Base64.decode(#{base64.inspect})
      EOS
  end

  i += 1
end

puts <<-EOS
  def __write(rendering)
  #{write_body.join("\n")}
  end
  EOS
