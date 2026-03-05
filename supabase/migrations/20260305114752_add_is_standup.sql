-- Add is_standup flag to movies table
ALTER TABLE movies ADD COLUMN IF NOT EXISTS is_standup BOOLEAN DEFAULT false;

-- Flag standup specials by known comedian names
UPDATE movies SET is_standup = true
WHERE title ILIKE ANY(ARRAY[
  '%bill burr:%', '%tom segura:%', '%dave chappelle:%',
  '%john mulaney:%', '%neal brennan:%', '%kevin hart:%',
  '%jim gaffigan:%', '%bo burnham:%', '%hannah gadsby:%',
  '%ali wong:%', '%chris rock:%', '%ricky gervais:%',
  '%trevor noah:%', '%hasan minhaj:%', '%nate bargatze:%',
  '%bert kreischer:%', '%joe rogan:%', '%sebastian maniscalco:%',
  '%gabriel iglesias:%', '%jeff dunham:%', '%russell peters:%',
  '%vir das:%', '%kenny sebastian:%', '%zakir khan:%',
  '%biswa%rath:%', '%kanan gill:%', '%abhishek upmanyu:%',
  '%anubhav singh bassi:%', '%kapil sharma:%',
  '%amy schumer:%', '%iliza shlesinger:%', '%ellen degeneres:%',
  '%jerry seinfeld:%', '%aziz ansari:%', '%jim jefferies:%',
  '%jimmy carr:%', '%jack whitehall:%', '%marc maron:%',
  '%mike birbiglia:%', '%jo koy:%', '%deon cole:%',
  '%chris d''elia:%', '%katherine ryan:%', '%katt williams:%',
  '%matt rife:%', '%leanne morgan:%', '%fortune feimster:%',
  '%chelsea handler:%', '%michelle buteau:%', '%michelle wolf:%',
  '%anthony jeselnik:%', '%louis c.k.:%', '%marlon wayans:%',
  '%franco escamilla:%', '%alan saldana:%', '%daniel sosa:%',
  '%felipe esparza:%', '%mau nieto:%', '%liss pereira:%',
  '%adam sandler: love%', '%adam devine:%',
  '%eric andre:%', '%joel kim booster:%', '%brian regan:%',
  '%demetri martin:%', '%greg davies:%', '%leslie jones:%',
  '%mike epps:%', '%andrew schulz:%', '%david spade:%',
  '%judd apatow:%', '%craig ferguson:%', '%ari shaffir:%',
  '%celeste barber:%', '%ronny chieng:%', '%taylor tomlinson:%',
  '%nikki glaser:%', '%sam morril:%', '%mark normand:%',
  '%brian simpson:%', '%dusty slay:%', '%hannah berner:%',
  '%marcello hernandez:%', '%michael che:%'
]);

-- Flag by "Name: Title" pattern + Comedy-only genres (<=2 genres, all Comedy/TV Movie)
-- This catches standup specials not in the comedian list above
UPDATE movies SET is_standup = true
WHERE is_standup = false
  AND title LIKE '%: %'
  AND (
    -- Single genre Comedy
    (jsonb_array_length(genres) = 1 AND genres @> '[{"name": "Comedy"}]')
    OR
    -- Two genres: Comedy + TV Movie
    (jsonb_array_length(genres) = 2 AND genres @> '[{"name": "Comedy"}]'
     AND genres @> '[{"name": "TV Movie"}]')
  );

-- Manually un-flag known false positives (real movies with "Name: Title" pattern)
UPDATE movies SET is_standup = false
WHERE title IN (
  'American Pie Presents: Beta House',
  'American Pie Presents: The Naked Mile',
  'Between Two Ferns: The Movie',
  'Deuce Bigalow: European Gigolo',
  'Impractical Jokers: The Movie',
  'F2: Fun and Frustration',
  'Handsome: A Netflix Mystery Movie',
  'Malibu Rescue: The Next Wave',
  'Daddy Cool: Join the Fun',
  'Chief Daddy 2: Going for Broke',
  'Good Game: The Beginning',
  'Graduation Trip: Mallorca',
  'Balls Out: Gary the Tennis Coach',
  'Jimmy Vestvood: Amerikan Hero',
  'Jatra: Hyalagaad Re Tyalagaad',
  'Kandasamys: The Baby',
  'Martabat: Misi Berdarah',
  'Hep Yek: Loto'
);
