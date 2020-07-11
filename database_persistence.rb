require "pg"

class DatabasePersistence
  def initialize(logger)
    @db = if Sinatra::Base.production?
        PG.connect(ENV['DATABASE_URL'])
      else
        PG.connect(dbname: "flashcards")
      end
    @logger = logger
  end

  def disconnect
    @db.close
  end

  def query(statement, *params)
    @logger.info "#{statement}: #{params}"
    @db.exec_params(statement, params)
  end

  def create_deck(name)
    sql = "INSERT INTO decks (name) VALUES ($1);"
    query(sql, name)
  end

  def edit_deck(deck_id, name)
    sql = <<~SQL
      UPDATE decks
      SET name = $1
      WHERE id = $2
    SQL

    query(sql, name, deck_id)
  end

  def delete_deck(deck_id)
    sql = "DELETE FROM decks WHERE id = $1"
    query(sql, deck_id)
  end

  def all_decks
    sql = <<~SQL
      SELECT *
      FROM decks
      ORDER BY name;
    SQL
    result = query(sql)

    result.map do |tuple|
      tuple_to_decks_hash(tuple)
    end
  end

  def find_deck(deck_id)
    sql = <<~SQL
      SELECT *
      FROM decks
      WHERE id = $1
    SQL

    result = query(sql, deck_id).first

    tuple_to_decks_hash(result)
  end

  def flashcards_for_deck(deck_id)
    sql = <<~SQL
      SELECT *
      FROM flashcards
      WHERE deck_id = $1
      ORDER BY id
    SQL

    result = query(sql, deck_id)

    result.map do |tuple|
      tuple_to_flashcard_hash(tuple)
    end
  end

  def find_flashcard(flashcard_id)
    sql = "SELECT * FROM flashcards WHERE id = $1"
    result = query(sql, flashcard_id)
    tuple_to_flashcard_hash(result.first)
  end

  def search_flashcards(deck_id, term)
    sql = <<~SQL
      SELECT *
      FROM flashcards
      WHERE deck_id = $1 
      AND front LIKE '%' || $2 || '%'
      OR back LIKE '%' || $2 || '%'
      ORDER BY id
    SQL

    result = query(sql, deck_id, term)

    result.map do |tuple|
      tuple_to_flashcard_hash(tuple)
    end
  end

  def create_flashcard(deck_id, front, back)
    sql = <<~SQL
      INSERT INTO flashcards (deck_id, front, back)
      VALUES ($1, $2, $3)
    SQL

    query(sql, deck_id, front, back)
  end

  def delete_flashcard(flashcard_id)
    sql = "DELETE FROM flashcards WHERE id = $1"
    query(sql, flashcard_id)
  end

  def edit_flashcard(flashcard_id, front, back)
    sql = <<~SQL
      UPDATE flashcards
      SET front = $2,
          back = $3
      WHERE id = $1
    SQL
    query(sql, flashcard_id, front, back)
  end

  private

  def tuple_to_decks_hash(tuple)
    { id: tuple['id'].to_i,
      name: tuple['name'] }
  end

  def tuple_to_flashcard_hash(tuple)
    { id: tuple['id'].to_i,
      deck_id: tuple['deck_id'].to_i,
      front: tuple['front'],
      back: tuple['back'] }
  end
end
