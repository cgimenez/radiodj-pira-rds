class RDJInputHandler

    def initialize(s)
        @s = s
    end

    def to_s
        @s
    end

    def convert_to_ascii(s)
        undefined = ''
        fallback = { 'À' => 'A', 'Á' => 'A', 'Â' => 'A', 'Ã' => 'A', 'Ä' => 'A',
                     'Å' => 'A', 'Æ' => 'AE', 'Ç' => 'C', 'È' => 'E', 'É' => 'E',
                     'Ê' => 'E', 'Ë' => 'E', 'Ì' => 'I', 'Í' => 'I', 'Î' => 'I',
                     'Ï' => 'I', 'Ñ' => 'N', 'Ò' => 'O', 'Ó' => 'O', 'Ô' => 'O',
                     'Õ' => 'O', 'Ö' => 'O', 'Ø' => 'O', 'Ù' => 'U', 'Ú' => 'U',
                     'Û' => 'U', 'Ü' => 'U', 'Ý' => 'Y', 'à' => 'a', 'á' => 'a',
                     'â' => 'a', 'ã' => 'a', 'ä' => 'a', 'å' => 'a', 'æ' => 'ae',
                     'ç' => 'c', 'è' => 'e', 'é' => 'e', 'ê' => 'e', 'ë' => 'e',
                     'ì' => 'i', 'í' => 'i', 'î' => 'i', 'ï' => 'i', 'ñ' => 'n',
                     'ò' => 'o', 'ó' => 'o', 'ô' => 'o', 'õ' => 'o', 'ö' => 'o',
                     'ø' => 'o', 'ù' => 'u', 'ú' => 'u', 'û' => 'u', 'ü' => 'u',
                     'ý' => 'y', 'ÿ' => 'y' }
        s.encode('ASCII',
                 fallback: lambda { |c| fallback.key?(c) ? fallback[c] : undefined })
      end

    def conform!()
        #
        # Welcome to the UTF / ISO / Mix - RadioDJ does not seems to convert anything
        # The strings are provided 'as is', from audio waves files tags
        #
        @s.force_encoding(Encoding::ISO_8859_1)
        @s = convert_to_ascii(@s)
    end

    def clean(data)
        return '' unless data
        data = data.gsub(/[^0-9a-zA-Z_ ()'&]/i, '') # Alphanumeric only
        data = data.gsub(/_/, ' ') # under scores to spaces
        data = data.gsub(/^Piste/, '')
        data = data.gsub(/^Track/, '')
        data = data.gsub(/^\d+/, '')
        data = data.squeeze(' ') # no multiple spaces
        data = data.capitalize
        data = data.strip
        data
    end

    def decode
        artist = ''
        title = ''
        category = -1
        duration = -1

        @s.split('^').each do |e1|
            values = e1.split('=')
            case values[0]
                when 'ARTIST'
                    artist = clean(values[1])
                when 'TITLE'
                    title = clean(values[1])
                when 'TYPE'
                    category = values[1].to_i
                when 'DURATION'
                    duration = values[1].to_i
            end
        end

        title = title[0..40]
        artist = artist[0..16]
        return artist, title, category, duration
    end

end