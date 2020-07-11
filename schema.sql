CREATE TABLE decks (
    id serial PRIMARY KEY,
    name text NOT NULL UNIQUE
);

CREATE TABLE flashcards (
    id serial PRIMARY KEY,
    deck_id integer REFERENCES decks (id) ON DELETE CASCADE NOT NULL,
    front text NOT NULL,
    back text NOT NULL
);
