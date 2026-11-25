# RoomCraft

Projekt semestralny w Godot 4, napisany w GDScript. Moduł mebli powstał w gałęzi `feature/furniture`, interfejs w `feature/ui`, a zapis i odczyt projektu w `feature/save`.

## Uruchomienie

Otwórz `project.godot` w Godot 4.7.2. Naciśnij F5, aby uruchomić projekt, lub otwórz scenę `scenes/Room.tscn` i naciśnij F6. W systemie Windows można też uruchomić wyeksportowany plik `RoomCraft.exe`.

## Katalog i edycja wyposażenia

Katalog prototypu zawiera 28 przedmiotów z miniaturami. Geometrię i materiały generuje kod projektu, bez zewnętrznych modeli. Poniższa tabela przedstawia podstawowe meble.

| ID | Przedmiot | Szerokość × wysokość × głębokość [m] |
| --- | --- | --- |
| table | Stół | 1.4 × 0.75 × 0.8 |
| chair | Krzesło | 0.5 × 0.9 × 0.55 |
| sofa | Sofa | 2.0 × 0.85 × 0.9 |
| armchair | Fotel | 0.9 × 0.85 × 0.85 |
| bed | Łóżko | 1.6 × 0.95 × 2.1 |
| wardrobe | Szafa | 1.2 × 2.0 × 0.6 |
| bookshelf | Regał | 0.8 × 1.8 × 0.35 |
| desk | Biurko | 1.2 × 0.75 × 0.6 |
| nightstand | Szafka nocna | 0.45 × 0.5 × 0.4 |
| coffee_table | Stolik kawowy | 1.0 × 0.4 × 0.6 |

### Sterowanie

- Kliknij miniaturę w katalogu po prawej stronie. Przewijaj listę, aby zobaczyć wszystkie przedmioty. Najedź na miniaturę, aby sprawdzić wymiary. Ponowne kliknięcie pozwala dodać kolejny egzemplarz. Klawisz T wybiera stół. Zielony podgląd oznacza, że można ustawić przedmiot, a czerwony wskazuje niedozwoloną pozycję.
- Lewy przycisk myszy zatwierdza pozycję lub zaznacza istniejący przedmiot na żółto.
- G rozpoczyna przenoszenie. Kliknij lewym przyciskiem myszy, aby zatwierdzić, lub naciśnij Esc, aby anulować. Do zatwierdzenia przedmiot pozostaje na miejscu.
- Krótkie naciśnięcie Q, E lub przycisku obrotu przesuwa przedmiot do kolejnej wielokrotności 15° w danym kierunku. Po przytrzymaniu przez 0,25 s obrót jest płynny (90°/s). Zwolnienie przycisku, opuszczenie go kursorem lub utrata fokusu zatrzymuje obrót. Program sprawdza kolizje na każdym kroku. Delete usuwa przedmiot, a Esc anuluje ustawianie.
- W/S przesuwa kamerę do przodu i do tyłu w poziomie, A/D na boki, a Page Up i Page Down w pionie. Shift trzykrotnie zwiększa prędkość. Prawy przycisk myszy obraca kamerę, środkowy przesuwa widok, kółko zmienia przybliżenie, a R przywraca widok początkowy. Podczas wpisywania wymiarów ruch kamery jest wyłączony. Po kliknięciu „Zastosuj wymiary” klawisze WASD ponownie sterują kamerą.

Program sprawdza prostokątny obrys mebla na płaszczyźnie XZ metodą osi rozdzielających (SAT), także po obrocie. Krawędzie mogą się stykać. Obrysy nie mogą się przecinać. Przy ścianie program uwzględnia połowę jej grubości (0,05 m). Umieszczanie mebla pod stołem nie jest obsługiwane.

## Wspólny interfejs modułów

Węzeł `FurnitureRoot` korzysta ze skryptu `FurnitureSystem`. Przedmioty `FurnitureItem` są jego bezpośrednimi dziećmi. Pozycje podaje się względem tego węzła w metrach. Dla przedmiotu na podłodze Y = 0, dla dekoracji na meblu Y odpowiada wysokości powierzchni, a dla okna wysokości dolnej krawędzi. Węzły główne pokoju i mebli wymagają zerowego przesunięcia i obrotu oraz skali jednostkowej.

### Metody publiczne

- `get_catalog()` zwraca kopię słownika 28 typów wyposażenia z polami `name` i `size`.
- `spawn_furniture(type_id, position, support_id = "", yaw = 0.0)` tworzy obiekt `FurnitureItem` lub zwraca `null` w razie błędu.
- `begin_placement(type_id)`, `begin_move_selected()` i `cancel_placement()` rozpoczynają ustawianie, rozpoczynają przenoszenie lub anulują operację.
- `move_selected(position)` i `rotate_selected(angle)` zwracają `bool`. Kąt oznacza przyrost obrotu wokół osi Y w radianach.
- `rotate_active(angle)` obraca aktywny podgląd lub zaznaczony przedmiot. Metodę wywołują przyciski obrotu oraz Q i E.
- `delete_selected()` usuwa zaznaczony przedmiot.
- `get_all_furniture()` zwraca tablicę słowników z polami `id` (losowy identyfikator 128-bitowy), `type_id`, `position` ([x, y, z]), `rotation_y` (radiany), `placement` (`floor` lub `wall`), `wall_id` (dla okien) i `support_id` (identyfikator podpory lub pusty tekst). Podgląd nie trafia do zapisu. Przenoszenie i obrót zachowują ID. Metoda `restore_furniture(records)` odtwarza przedmioty z pierwotnymi identyfikatorami.

Moduł wysyła sygnały `selection_changed(item)` (z wartością `null` po usunięciu zaznaczenia), `furniture_changed` oraz `status_changed(message)`.

Uczestnik 3 może zastąpić węzeł `FurnitureDebugUI` docelowym interfejsem korzystającym z tych metod. Pełnoekranowe węzły nadrzędne typu Control powinny mieć ustawienie `MOUSE_FILTER_IGNORE`. Panele obsługują mysz w zwykły sposób. Warstwa fizyczna 2 służy do wskazywania mebli, a warstwa 1 do obsługi pokoju.

### Integracja z modułem pokoju uczestnika 1

- `RoomController.add_room_size_validator(Callable)` rejestruje kontrolę, która przed zmianą wymiarów sprawdza, czy meble zmieszczą się w nowych granicach.
- Kamera ignoruje sterowanie nad panelami i podczas wpisywania wymiarów.
- Ściany od strony kamery są ukrywane, aby odsłonić wnętrze. Nadal uczestniczą w wykrywaniu kolizji.
- Scena ma oświetlenie otoczenia i jest ustawiona jako scena startowa projektu.

## Testy

Uruchom polecenia z katalogu głównego repozytorium. W razie potrzeby zastąp `godot` ścieżką do konsolowej wersji programu.

```powershell
godot --headless --editor --import --quit --path .
godot --headless --path . --script res://tests/furniture_test.gd
godot --headless --path . --script res://tests/furniture_catalog_test.gd
godot --headless --path . --script res://tests/window_test.gd
godot --headless --path . --script res://tests/room_camera_test.gd
godot --headless --path . --script res://tests/settings_alignment_test.gd
godot --headless --path . --script res://tests/surface_placement_test.gd
godot --headless --path . --script res://tests/decor_collision_test.gd
godot --path . --script res://tests/decor_placement_interaction_test.gd
godot --path . --script res://tests/surface_interaction_test.gd
godot --path . --script res://tests/input_regression_test.gd
godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 --script res://tests/furniture_interaction_test.gd
```

Ostatni test wykorzystuje oddzielny widok SubViewport i symulowane zdarzenia myszy. Sprawdza wskazywanie promieniem, przenoszenie i blokadę interakcji nad panelem bez poruszania kursorem systemowym. Test katalogu sprawdza wymiary widocznych modeli, operacje i przywracanie materiałów wszystkich typów podłogowych. `FurnitureThumbnail` jednokrotnie renderuje miniaturę w oddzielnym SubViewport. Docelowy interfejs może wykorzystywać ten sam komponent.

Test ręczny: ustaw dwa stoły, spróbuj nałożyć jeden na drugi i przesunąć go za ścianę. Obróć stół przy ścianie, anuluj przenoszenie, spróbuj zmniejszyć pokój tak, aby przeciął mebel, a na koniec usuń przedmiot. Odrzucona operacja powinna zachować wcześniejszy układ.

## Praca zespołowa

Zmiany modułu mebli trafiają do `feature/furniture`. Zespół przegląda zmiany przed scaleniem ich z `main` przez pull request. Przed rozpoczęciem pracy wykonaj `git fetch origin`. Unikaj wymuszonego wysyłania zmian do wspólnych gałęzi.


## Kuchnia, łazienka i dekoracje

Lista kategorii zawiera opcje `Wszystko`, `Meble`, `Dekoracje`, `Kuchnia`, `Łazienka` i `Okna`. Katalog można przewijać. Podpowiedzi przy miniaturach pokazują wymiary. Interfejs może odczytywać opcjonalne pola `category` (domyślnie `Meble`) i `placement` (domyślnie `floor`).

| ID | Przedmiot | Szerokość × wysokość × głębokość [m] |
| --- | --- | --- |
| window | Okno | 1.2 × 1.1 × 0.16 |
| tv_console | Telewizor z szafką RTV | 1.4 × 1.25 × 0.4 |
| plant | Duża roślina doniczkowa | 0.65 × 1.3 × 0.65 |
| flowers | Kwiaty w doniczce | 0.45 × 0.7 × 0.45 |
| floor_lamp | Lampa podłogowa | 0.45 × 1.65 × 0.45 |
| kitchen_cabinet | Szafka kuchenna z blatem | 0.6 × 0.9 × 0.6 |
| kitchen_sink | Zlewozmywak z szafką i baterią | 0.8 × 1.15 × 0.6 |
| cooker | Kuchenka z piekarnikiem | 0.6 × 0.9 × 0.6 |
| fridge | Lodówka | 0.7 × 1.85 × 0.7 |
| dishwasher | Zmywarka | 0.6 × 0.85 × 0.6 |
| kitchen_island | Wyspa kuchenna | 1.5 × 0.9 × 0.8 |
| bathtub | Wanna | 0.8 × 0.6 × 1.7 |
| toilet | Toaleta | 0.42 × 0.8 × 0.7 |
| bathroom_vanity | Umywalka z szafką i baterią | 0.7 × 1.05 × 0.5 |
| shower | Kabina prysznicowa | 0.9 × 2.1 × 0.9 |
| washing_machine | Pralka | 0.6 × 0.85 × 0.6 |

Modele służą do planowania przestrzeni. Drzwi urządzeń i skrzydła okien pozostają zamknięte. Projekt nie symuluje przepływu wody ani działania urządzeń. Telewizor i szafka tworzą jeden przedmiot. Kwiaty, małą roślinę i lampkę stołową można ustawić na podłodze lub na odpowiednim meblu. Okna mocuje się do ścian, a pozostałe przedmioty ustawia na podłodze.

## Okna i otwory w ścianach

1. W katalogu wybierz **Okna → Okno**.
2. Wskaż widoczną ścianę. Środek okna podąża za kursorem w odstępach co 5 cm. Zielony podgląd oznacza poprawne położenie, czerwony sygnalizuje błąd.
3. Kliknij lewym przyciskiem myszy, aby zamontować okno. Aby je przenieść, zaznacz je, naciśnij G i wskaż miejsce na tej samej lub innej ścianie. Esc anuluje przenoszenie, a Delete usuwa okno i zamyka otwór.
4. Okno automatycznie ustawia się równolegle do ściany. Klawisze Q/E są dla niego wyłączone. Jeśli bliższa ściana jest ukryta, obróć kamerę, aby zobaczyć i edytować znajdujące się w niej okno.

Ściany składają się z prostokątnych segmentów wokół okien, więc otwory występują zarówno w geometrii, jak i w bryłach kolizji. Jedna ściana może mieć kilka rozłącznych okien. Ramy muszą mieścić się między narożnikami, podłogą i sufitem. Zmniejszenie pokoju zostanie odrzucone, jeśli przecina okno lub powoduje kolizję. Przy poprawnej zmianie okno przesuwa się razem ze ścianą, zachowując wysokość i położenie wzdłuż niej.

Kontrola uwzględnia wysokość przedmiotów. Niska szafka mieści się pod parapetem, ale wysoka szafa nie może przecinać ramy. Dla mebli podłogowych program uwzględnia cały obrys, łącznie z przestrzenią między nogami.

### Metody obsługi okien

- `spawn_window(wall_id, offset, bottom = 1.0)` zwraca okno lub `null`. Dostępne ściany to `FrontWall` (−Z), `BackWall` (+Z), `LeftWall` (−X) i `RightWall` (+X). Parametr `offset` określa współrzędną X dla ściany przedniej i tylnej lub Z dla lewej i prawej. Parametr `bottom` podaje wysokość dolnej krawędzi.
- `spawn_furniture("window", ...)` odrzuca żądanie, ponieważ okno wymaga przypisania do ściany.
- `RoomController.set_window_openings(openings)` przekazuje otwory do RoomGeometry. FurnitureSystem aktualizuje je po dodaniu, przeniesieniu i usunięciu okna oraz po zmianie wymiarów pokoju.
- Rekord okna zawiera `wall_id`, `placement`, `position` z wysokością dolnej krawędzi oraz `rotation_y`. Moduł zapisu obsługuje plik JSON, a `restore_furniture` przywraca identyfikatory.

Test ręczny okien: zamontuj dwa okna w jednej ścianie, przenieś jedno na inną ścianę, rozpocznij i anuluj kolejne przenoszenie, zmień wymiary pokoju i usuń okno. Otwór powinien podążać za oknem i zniknąć po jego usunięciu.


Przycisk zmiany wymiarów odczytuje oba pola przed przebudową pokoju. Po niedozwolonym zmniejszeniu wyświetla komunikat i przywraca faktyczne wymiary w polach. Można od razu wpisać kolejne wartości. Test `room_camera_test.gd` sprawdza ponowne zatwierdzanie, przywracanie pól po błędzie, mocowanie okna i sterowanie kamerą z klawiatury.


## Wprowadzanie wymiarów i sterowanie

Pola wymiarów korzystają z LineEdit. Przyjmują cyfry i jeden separator dziesiętny (przecinek lub kropkę), np. `6,5` lub `4.25`. Litery i operatory są blokowane, a wklejany tekst jest filtrowany. Pole nie oblicza wyrażeń. Przycisk zatwierdzenia lub Enter odczytuje bieżący tekst obu pól. Utrata fokusu zachowuje wpisany tekst. Puste pola i wartości spoza zakresu 2–30 m nie zmieniają pokoju.

Użycie WASD włącza swobodny lot. Prawy przycisk myszy obraca kamerę w miejscu, a kółko przesuwa ją o mały krok w kierunku patrzenia. W/S zachowuje wysokość, którą zmienia się klawiszami PgUp/PgDn. Promień lotu zależy od przekątnej pokoju i wynosi co najmniej 20 m od środka. Zakres wysokości wynosi 0,2–15 m. Klawisz R przywraca początkowy widok orbitalny i jego środek obrotu.

Do obsługi przytrzymania przycisku służą metody FurnitureSystem: `start_rotation(source, direction)` (kierunek −1 lub +1), `stop_rotation(source)` i `stop_all_rotation()`. Nadaj każdemu przyciskowi osobny identyfikator, np. `ui_left` i `ui_right`. Zatrzymaj obrót po zdarzeniu `button_up` lub `mouse_exited`. Okna automatycznie dopasowują orientację do ściany.

Test `input_regression_test.gd` symuluje wpisywanie kolejnych cyfr i separatorów dziesiętnych, blokowanie liter, filtrowanie wklejonego tekstu, obrót kamery po locie oraz ciągły obrót mebla z kontrolą kolizji. Używa osobnego widoku i pozostawia kursor systemowy na miejscu.


## WASD, czułość kamery i wyrównywanie mebli

- Ruch kamery wykorzystuje fizyczne klawisze W/A/S/D niezależnie od układu klawiatury. PgUp/PgDn, Shift i R działają tak jak opisano w sekcji o sterowaniu.
- Suwak **Czułość kamery** pod polami wymiarów zmienia czułość obrotu myszą w zakresie od 0,25× do 3×. Ustawienie obowiązuje podczas bieżącej sesji. Naciśnięcie R zachowuje wybraną czułość.
- W tej wersji szerokość i długość pokoju mogą wynosić od 2 do 30 m. Kontroler i interfejs korzystają ze stałych `RoomGeometry.MIN_ROOM_SIZE` i `MAX_ROOM_SIZE`. Widok i zasięg kamery dostosowują się do wielkości pokoju.
- Po płynnym obrocie krótkie naciśnięcie Q lub E ustawia najbliższy kąt siatki w wybranym kierunku. Dla 38° klawisz Q ustawia 30°, a E ustawia 45°. Kolejne E zmienia 45° na 60°.
- Klawisz F lub przycisk **Wyrównaj do ścian** obraca zaznaczony mebel albo podgląd do najbliższej osi pokoju (0°, 90°, 180° lub 270°), zachowując jego pozycję. Okna są już ustawione równolegle do ścian.
- Panel pokazuje bieżący kąt. Podczas wyrównywania ustawionego mebla program sprawdza cały tor obrotu. Jeśli przeszkadza ściana lub inny przedmiot, mebel zachowuje pierwotny kąt.

Interfejs uczestnika 3 może wywołać `FurnitureSystem.align_active() -> bool`. Przytrzymanie Q/E nadal obraca płynnie, a krótkie naciśnięcie ustawia dokładny kąt.


## Dekoracje na meblach i urządzeniach

Na meblach można ustawiać **Kwiaty**, **Lampkę stołową** (0,28 × 0,45 × 0,28 m) i **Małą roślinę** (0,30 × 0,55 × 0,30 m). Lampka i mała roślina należą do kategorii `Dekoracje`. Duża roślina doniczkowa i lampa podłogowa stoją na podłodze.

Dekoracje można postawić na stole, stoliku kawowym, biurku, szafce nocnej, szafce kuchennej, wyspie kuchennej, pralce, zmywarce i lodówce. Kuchenka, zlewozmywak, umywalka, sofa, krzesło, łóżko, telewizor i same dekoracje nie służą jako podpory.

Wybierz dekorację i wskaż górną powierzchnię mebla. Podgląd dopasuje wysokość. Kliknij lewym przyciskiem myszy, aby zatwierdzić. Klawiszem G przeniesiesz dekorację na inny mebel lub na podłogę. Najłatwiej wskazać blat z góry. Podpowiedź w katalogu pokazuje dostępne sposoby ustawienia, a panel podaje wysokość przedmiotu.

### Reguły rozmieszczania

- Cała podstawa doniczki lub lampki musi mieścić się na blacie. Blisko krawędzi program koryguje pozycję. Liście i klosz mogą wystawać poza blat, o ile nie przecinają ścian, sufitu ani innych przedmiotów.
- Dekoracja nie może przecinać drugiego przedmiotu na tej samej powierzchni, okna ani sufitu. Nie można ustawić jej w powietrzu, na nieistniejącej podporze ani na niej samej.
- Podczas przenoszenia i obracania mebla dekoracje poruszają się razem z nim i są widoczne w podglądzie. Kolizja lub przekroczenie granicy przez dowolny element blokuje całą operację.
- Przed usunięciem mebla przenieś lub usuń stojące na nim dekoracje. Zapobiega to ich zniknięciu lub pozostawieniu w powietrzu.
- Obsługiwany jest jeden poziom: mebel na podłodze i dekoracja na meblu. Nie można układać mebli jeden na drugim ani piętrować doniczek.

### Metody obsługi dekoracji

- `get_catalog()` udostępnia flagę `stackable` dla dekoracji i `surface` dla podpór. Brak flagi oznacza `false`. Pole `footprint: Vector2` określa wymiary podstawy dekoracji, a `size` pełne wymiary modelu.
- `spawn_on_surface(type_id, support_id, offset = Vector2.ZERO)` tworzy przedmiot na podporze. Parametr `offset` określa przesunięcie względem środka dostępnej powierzchni w lokalnych osiach XZ podpory. Przedmiot dziedziczy jej obrót. W razie błędu metoda zwraca `null`.
- `spawn_furniture(type_id, position, support_id = "", yaw = 0.0)` przyjmuje wysokość, orientację i identyfikator istniejącej podpory. Przedmioty bez podpory można ustawić wyłącznie na podłodze.
- `move_selected(position, support_id = "")` przenosi zaznaczony przedmiot. Przy zmianie podpory podaj jej ID i dokładną wysokość. Pozycja z Y = 0 przenosi dekorację na podłogę i usuwa powiązanie. Podczas przesuwania po tym samym blacie można zachować dotychczasowe ID.
- `FurnitureItem.support_id` i pole `support_id` w `to_record()` oraz `get_all_furniture()` przechowują powiązanie z podporą. Przedmioty pozostają bezpośrednimi dziećmi FurnitureRoot, a ich pozycje są podawane względem pokoju. Metoda `restore_furniture(records)` odtwarza identyfikatory i powiązania niezależnie od kolejności rekordów. Pliki JSON odczytuje moduł zapisu.

Testy obejmują ustawianie na szafce i pralce, ograniczenia typów i wymiarów, oddzielne zaznaczanie dekoracji, powrót na podłogę, przenoszenie i obrót grupy, anulowanie, blokadę usunięcia zajętej podpory, dane zapisu oraz wskazywanie powierzchni myszą.


## Dokładność wykrywania kolizji małych dekoracji

Dla pary małych przedmiotów (`flowers`, `potted_plant`, `table_lamp`) program najpierw sprawdza ich obrysy, a następnie wypukłe części modeli, m.in. podstawy, nóżki, doniczki, klosze i liście. Wolna przestrzeń między częściami pozwala dosunąć drugi przedmiot. Przy dużych meblach nadal uwzględnia się pełny obrys.

Przy wybieraniu dekoracji myszą promień może przejść między liśćmi lub obok nóżki i trafić w blat. Wszystkie trzy typy mają oznaczenie `round_base: true`, więc obrót nie zwiększa promienia zajmowanego na blacie. Nadal obowiązują ograniczenia krawędzi blatu, ścian, sufitu i kolizji rzeczywistych części.

Podgląd wskazuje powód odrzucenia pozycji, np. przekroczenie granicy pokoju, brak podpory, wskazanie boku zamiast blatu lub kolizję z konkretnym przedmiotem.

Test `decor_collision_test.gd` sprawdza ustawienia, w których nakładają się obrysy, ale modele się nie stykają. Sprawdza też przejście promienia przez lukę i porównuje algorytm z niezależnymi zapytaniami silnika fizycznego dla brył wypukłych w 72 pozycjach i orientacjach. Test graficzny sprawdza ustawienie sąsiedniej lampki kliknięciem i odrzucenie rzeczywistej kolizji.


## Odtwarzanie układu wyposażenia

`FurnitureSystem.restore_furniture(records)` przyjmuje tablicę z `get_all_furniture()`, także po odczycie z JSON. Zwraca `{"ok": true, "error": ""}` albo `{"ok": false, "error": "opis błędu"}`. Przy wywołaniu z samymi rekordami odtwarza wyposażenie w pokoju o bieżących wymiarach. Zachowuje identyfikatory, pozycje, kąty obrotu, przypisanie okien do ścian i dekoracji do podpór. Pusta tablica usuwa wyposażenie i zamyka otwory okienne.

Przed zmianą sceny moduł sprawdza typy pól, skończoność liczb, unikalność ID, zgodność z katalogiem, granice pokoju, podpory i kolizje. W razie błędu zachowuje wyposażenie, zaznaczenie, podgląd i otwory okienne. Po powodzeniu kończy edycję, usuwa zaznaczenie i raz wysyła sygnał `furniture_changed`. W starszych rekordach przedmiotów podłogowych pola `placement`, `wall_id` i `support_id` są opcjonalne. Pozostałe pola są wymagane. ID musi być niepustym ciągiem znaków.

```gdscript
var result = furniture_system.restore_furniture(saved_data.get("furniture"))
if not result.ok:
    show_load_error(result.error)
```

Uczestnik 4 odpowiada za wersję formatu, zapis i odczyt plików JSON, obsługę błędów oraz parametry pokoju. Przy wczytywaniu projektu o innych wymiarach moduł sprawdza rozmieszczenie w granicach zapisanych w pliku. Nowe wymiary, kolory i wyposażenie stosuje dopiero po poprawnym sprawdzeniu danych.

Interfejs korzysta z publicznych metod i sygnałów modułu mebli. Przyciski zapisu i odczytu wywołują moduł zapisu projektów.

Test regresji uruchamia polecenie `godot --headless --path . --script res://tests/furniture_restore_test.gd`. Obejmuje zapis i odtworzenie danych JSON, okna, dekorację zapisaną przed podporą, zachowanie ID, błędne rekordy, pusty układ i starszy format danych.

## Zapis, odczyt i wydanie Windows (uczestnik 4)

W menu głównym wybierz **Nowy projekt** i podaj nazwę albo wybierz **Wczytaj projekt**. Przycisk **Zapisz zmiany** zapisuje bieżący projekt. Menu **Wczytaj projekt** pokazuje folder zapisu i umożliwia otwarcie go w Eksploratorze. Projekty pomyślnie otwarte z dysku pojawiają się na liście także po ponownym uruchomieniu aplikacji. Zmiany są zapisywane do otwartego pliku, którego ścieżkę pokazuje podpowiedź przycisku **Zapisz zmiany**. Format v1 obejmuje szerokość i długość w metrach, kolory RGBA ścian i podłogi oraz komplet rekordów z `FurnitureSystem.get_all_furniture()`. Zapis obejmuje zatwierdzone przedmioty. Przy odczycie wymiary są sprawdzane według ograniczeń bieżącej wersji RoomGeometry. Błędny plik pozostawia dotychczasowy pokój i rozpoczętą edycję bez zmian.

UI może wywołać `ProjectStore.save_project(path, room)` (kod Error) oraz `ProjectStore.load_project(path, room)` (słownik z polem ok i komunikatem error w razie błędu).

Test i eksport (Godot 4.7.2 oraz odpowiadające mu szablony eksportu):

~~~powershell
godot --headless --editor --import --quit --path .
godot --headless --path . --script res://tests/project_store_test.gd
godot --headless --path . --script res://tests/furniture_restore_test.gd
New-Item -ItemType Directory -Force build
godot --headless --path . --export-release "Windows Desktop" build/RoomCraft.exe
~~~

Test ręczny wydania: uruchom RoomCraft.exe, zmień wymiary, dodaj stół, lampę na stole i okno. Zapisz projekt, zamknij program, uruchom ponownie i wczytaj plik. Sprawdź otwór okienny, położenie lampy, rozmiary oraz kolor pokoju. Wczytaj uszkodzony plik i upewnij się, że poprzedni pokój pozostał na ekranie.
