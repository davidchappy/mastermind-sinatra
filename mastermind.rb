require 'sinatra'
require 'sinatra/reloader' if development?

enable :sessions
set :session_secret, 'mastermind_secret'

$turn_limit = 12

get '/' do
  @guesses = session[:guesses] ||= []  
  p session[:guesses].inspect
  if @guesses.length >= $turn_limit
    redirect to('/lost')
  end
  @feedback = session[:feedback] ||= []
  p @feedback
  @turn_count = @guesses.length
  @code = session[:code] = generate_code if session[:code].nil?

  # guesses = [[1,1,1,1], [1,2,3,4]]
  # answers = [["r","w","r","b"], ["r","w","r","w"]]

  erb :index, :locals => {:turn_limit => $turn_limit, :turn_count => @turn_count, :guesses => @guesses, :feedback => @feedback}
end

post '/' do
  session[:guesses] ||= []
  session[:guesses] << params[:guess]  
  session[:feedback] << process_guess(params[:guess])
  redirect to('/')
end

get '/won' do
  won = true
  erb :end, :locals => {:won => won, :code => session[:code]}
end

get '/lost' do
  won = false
  erb :end, :locals => {:won => won, :code => session[:code]}
end

get '/restart' do
  session[:guesses] = []
  session[:feedback] = []
  session[:code] = nil
  redirect to('/')
end

helpers do

  def generate_code
    code = []
    4.times { |r| code << rand(1..6) }
    code.join("") 
  end

  def process_guess(guess)  
    code = session[:code]
    if guess == code
      redirect to('/won')
    else
      # set up the answer and code as arrays for comparison
      guess_array = guess.split("")
      code_array = code.split("")

      results = {bagels: 0, picos: 0, fermis: 0}
      pegs_counted = 0
      duplicates = []

      # get counts of each digit in code and answer arrays
      code_counts = code_array.inject(Hash.new(0)) { |total, e| total[e] += 1 ;total}
      guess_counts = guess_array.inject(Hash.new(0)) { |total, e| total[e] += 1 ;total}

      # operate on @answer_array until 4 pegs have been counted
      until pegs_counted == 4
        guess_array.each_with_index do |number, index|
          if code_array.include?(number)
            if code_array[index] == number  # add bagels
              pegs_counted += 1
              results[:bagels] += 1
            else  # add picos  
              results[:picos] += 1 
              pegs_counted += 1 
              if guess_counts[number] > code_counts[number]
                duplicates << number unless duplicates.include?(number)
              end
            end
          else # add fermis
            pegs_counted += 1
            results[:fermis] += 1
          end
        end
      end

      # compensate for picos that were overcounted 
      unless duplicates.nil?
        duplicates.each do |duplicate|
          code_counts[duplicate] ||= 0
          difference = guess_counts[duplicate] - code_counts[duplicate]
          results[:picos] -= difference
          results[:fermis] += difference
        end
      end

      feedback = []
      results.each do |type,quantity|
        case type
        when :bagels
          quantity.times { feedback << "r" }
        when :picos
          quantity.times { feedback << "w" }
        when :fermis
          quantity.times { feedback << "b" }
        end
      end
          
      return feedback
    end
    
  end

end