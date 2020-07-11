require "sinatra"
require "sinatra/content_for"
require "tilt/erubis"
require_relative "database_persistence"

require "sinatra/reloader" if development?

before do
  @storage = DatabasePersistence.new(logger)
  session[:deck_id_to_flashcard_ids] ||= {}
end

after do
  @storage.disconnect
end

configure do
  enable :sessions
  set :session_secret, 'secret'
end

def error_for_deck_name(deck_name)
  if !(1..50).include?(deck_name.size)
    "Deck name must be 1 to 50 characters long"
  elsif deck_name.match?(/[^a-zA-Z0-9 ]/)
    "Deck name must only consist of letters, numbers and spaces"
  elsif @storage.all_decks.any? { |deck_hash| deck_hash[:name] == deck_name }
    "You already have a deck with that name"
  end
end

def error_for_flashcard(front, back)
  if front.empty? || back.empty?
    "Front and Back cannot be empty"
  elsif front.size >= 280 || back.size >= 280
    "Front and Back must be less than 280 characters"
  end
end

def load_flashcard_ids(deck_id)
  decks_flashcard_ids = session[:deck_id_to_flashcard_ids]

  if !decks_flashcard_ids[deck_id]
     flashcard_ids = @storage.flashcards_for_deck(deck_id)
                             .map { |flashcard| flashcard[:id] }

    decks_flashcard_ids[deck_id] = flashcard_ids.shuffle
  else
    decks_flashcard_ids[deck_id]
  end
end

get "/" do
  @decks = @storage.all_decks
  erb :decks, layout: :layout
end

# view create deck form
get "/new" do
  erb :new_deck
end

# create deck
post "/" do
  deck_name = params[:deck_name].strip
  error = error_for_deck_name(deck_name)

  if error
    session[:message] = error
    erb :new_deck
  else
    @storage.create_deck(deck_name)
    session[:message] = "Deck has been created"
    redirect "/"
  end
end

# view deck
get "/:id" do
  @deck = @storage.find_deck(params[:id])

  erb :deck
end

# delete deck
post "/:id/delete" do
  @storage.delete_deck(params[:id])
  session[:message] = "Deck has been deleted"
  redirect "/"
end

# view edit deck form
get "/:id/edit" do
  @deck = @storage.find_deck(params[:id].to_i)
  erb :edit_deck
end

# edit deck
post "/:id/edit" do
  deck_id = params[:id].to_i
  deck_name = params[:deck_name].strip
  error = error_for_deck_name(deck_name)

  if error
    session[:message] = error
    erb :edit_deck
  else
    @storage.edit_deck(deck_id, deck_name)
    session[:message] = "Deck has been updated"
    redirect "/"
  end
end

# view flashcards
get "/:id/flashcards" do
  @deck = @storage.find_deck(params[:id])
  @flashcards = @storage.flashcards_for_deck(params[:id])

  erb :flashcards
end

# search for flashcards
post "/:id/flashcards/search" do
  term = params[:term].strip

  if !(1..50).include?(term.size)
    session[:message] = "Search term must contain 1 to 50 characters"
    @deck = @storage.find_deck(params[:id])
    @flashcards = @storage.flashcards_for_deck(params[:id])
    erb :flashcards
  else
    redirect "/#{ params[:id] }/flashcards/search?term=#{ term }"
  end
end

get "/:id/flashcards/search" do
  @deck = @storage.find_deck(params[:id])
  @flashcards = @storage.search_flashcards(params[:id], params[:term].strip)
  erb :search_flashcards
end

# view form to create flashcard
get "/:id/flashcard" do
  erb :new_flashcard
end

# create flashcard
post "/:id/new" do
  front = params[:front].strip
  back = params[:back].strip
  error = error_for_flashcard(front, back)

  if error
    session[:message] = error
    erb :new_flashcard
  else
    @storage.create_flashcard(params[:id], front, back)
    session[:message] = "Flashcard created"
    redirect "/#{ params[:id] }"
  end
end

# delete flashcard
post "/:deck_id/:id/delete" do
  @storage.delete_flashcard(params[:id])
  session[:message] = "Flashcard deleted"
  redirect "/#{ params[:deck_id] }"
end

# view form to edit flashcard
get "/:deck_id/:id/edit" do
  @flashcard = @storage.find_flashcard(params[:id])
  erb :edit_flashcard
end

# edit flashcard
post "/:deck_id/:id/edit" do
  front = params[:front].strip
  back = params[:back].strip
  error = error_for_flashcard(front, back)

  if error
    session[:message] = error
    erb :edit_flashcard
  else
    @storage.edit_flashcard(params[:id], front, back)
    session[:message] = "Flashcard updated"
    redirect "/#{ params[:deck_id] }/flashcards"
  end
end

# Study flashcards
get "/:id/study" do
  deck_id = params[:id].to_i

  if !load_flashcard_ids(deck_id).empty?
    @flashcard = @storage.find_flashcard(session[:deck_id_to_flashcard_ids][deck_id].pop)
  end

  erb :study
end

# start deck over or repeat certain flashcards
post "/:id/study" do
  decks_flashcard_ids = session[:deck_id_to_flashcard_ids]
  deck_id = params[:id].to_i

  if params[:repeat]
    decks_flashcard_ids[deck_id].unshift(params[:repeat].to_i)
  elsif params[:start_over] || decks_flashcard_ids[deck_id]&.empty?
    decks_flashcard_ids.delete(params[:id].to_i)
  end

  redirect "/#{ params[:id] }/study"
end
