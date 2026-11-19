# White Sum - store listing (drafts)

Draft texts for App Store Connect: the TestFlight test information now, the App Store product page later. English is
the primary language; Dutch is the second localisation. Dutch versions are included here because they are store texts.
Technical background: `docs/design.md` section 16 and ADR 0007.

The texts describe the phase 1 content: 40 practice sets of three puzzles (easy, medium, hard), no daily puzzle yet.
Update them when the daily puzzle ships (phase 2). Do not promise features that are not built.

Limits in App Store Connect: name 30 characters, subtitle 30, promotional text 170, keywords 100 bytes, description
4000.

## 1. Identity

| Field | Value |
|---|---|
| App name | White Sum (both languages; 9 characters) |
| Bundle ID | `nl.steefbeest.whitesum` |
| SKU | `white-sum` |
| Primary language | English (U.K.) |
| Second localisation | Dutch |
| Primary category | Games > Puzzle |
| Secondary category | none (optional: Games > Family) |
| Price | Free, no in-app purchases |
| Copyright | Open: proposal `2026 ST33F` (owner decides; design section 15) |

## 2. Subtitle (max 30)

| Language | Text | Length |
|---|---|---|
| English | Make exactly ten | 16 |
| Dutch | Maak precies tien | 17 |

## 3. Promotional text (max 170)

English (131):

> Swap and slide numbered tiles until a row or column adds up to exactly 10 and vanishes. Clear the board in as few
> moves as you can.

Dutch (131):

> Wissel en schuif stenen met getallen tot een rij of kolom precies 10 is en verdwijnt. Maak het bord leeg in zo min
> mogelijk zetten.

## 4. Description (max 4000)

English:

```
White Sum is a calm number puzzle. Tiles numbered 1 to 5 sit on a board under gravity. Swap two neighbouring tiles, or slide one sideways into an empty spot. When touching tiles in a row or a column add up to exactly 10, they vanish. Tiles above fall down and can make ten again: a chain reaction. No new tiles ever appear.

Clear the board in as few moves as possible. Every puzzle shows its par: the smallest number of moves that works.

- 120 puzzles in 40 sets, each with an easy, a medium and a hard board
- Select a tile to see the totals of its row and its column
- Undo and restart as often as you like
- After you finish, watch the best route
- Dutch and English
- No ads, no account, no tracking; plays offline

White Sum is part of the White series: quiet, flat puzzle games without timers or pressure.
```

Dutch:

```
White Sum is een rustige rekenpuzzel. Stenen met een getal van 1 tot 5 liggen op een bord onder zwaartekracht. Wissel twee buurstenen, of schuif een steen opzij naar een lege plek. Raken stenen elkaar in een rij of kolom en is het totaal precies 10, dan verdwijnen ze. Wat erboven ligt, valt omlaag en kan weer op tien uitkomen: een kettingreactie. Er komen nooit nieuwe stenen bij.

Maak het bord leeg in zo min mogelijk zetten. Bij elke puzzel staat de par: het kleinste aantal zetten dat kan.

- 120 puzzels in 40 sets, elk met een makkelijk, een middel en een moeilijk bord
- Kies een steen en zie de totalen van zijn rij en zijn kolom
- Neem terug en begin opnieuw zo vaak je wilt
- Klaar? Bekijk de beste route
- Nederlands en Engels
- Geen advertenties, geen account, geen tracking; speelt offline

White Sum hoort bij de White-reeks: rustige, strakke puzzelspellen zonder tijdsdruk.
```

## 5. Keywords (max 100, comma-separated, no spaces)

Words already in the app name ("white", "sum") are not repeated.

| Language | Keywords | Length |
|---|---|---|
| English | `puzzle,numbers,math,ten,addition,logic,brain,tiles,gravity,calm,minimal,arithmetic,chain` | 88 |
| Dutch | `puzzel,rekenen,getallen,tien,optellen,som,logica,breinbreker,stenen,zwaartekracht,rustig` | 88 |

## 6. URLs

| Field | English | Dutch |
|---|---|---|
| Marketing URL | https://white-sum.steefbeest.nl/en/ | https://white-sum.steefbeest.nl/ |
| Support URL | https://white-sum.steefbeest.nl/en/ | https://white-sum.steefbeest.nl/ |
| Privacy policy URL | https://white-sum.steefbeest.nl/en/privacy/ | https://white-sum.steefbeest.nl/privacy/ |

The promo site lives in the repository `pulse` (`apps/white-sum-site`, shared layout in `packages/puzzle-site`). It
already has a contact address in the footer, so it serves as the support page. The privacy pages do not exist yet: the
site's privacy section speaks only of the browser version. A follow-up in `pulse` adds `/privacy/` and `/en/privacy/`
with the texts of section 7 (or widens the shared privacy text so it covers the app and the browser version).

## 7. Privacy policy

English:

```
Privacy - White Sum

White Sum has no accounts and no server for players. The app collects no personal data: it makes no network connections and contains no ads, no analytics and no trackers.

Your language choice is stored only on your device, in the app's own storage. It is not sent anywhere. It may be part of your device backup; deleting the app removes it.

If you test White Sum through TestFlight and send feedback or a crash report, Apple passes that feedback, the attached screenshot and basic device information on to the developer. It is used only to fix and improve the game and is not shared with anyone else.

The promo website white-sum.steefbeest.nl sets no cookies and uses no trackers.

Questions: privacy@steefbeest.nl

Last updated: 19 November 2026
```

Dutch:

```
Privacy - White Sum

White Sum heeft geen accounts en geen server voor spelers. De app verzamelt geen persoonsgegevens: hij maakt geen netwerkverbinding en bevat geen advertenties, geen analytics en geen trackers.

Je taalkeuze staat alleen op je toestel, in de eigen opslag van de app. Die wordt nergens naartoe gestuurd. Hij kan in de back-up van je toestel terechtkomen; verwijder je de app, dan is hij weg.

Test je White Sum via TestFlight en stuur je feedback of een crashrapport, dan geeft Apple die feedback, de bijgevoegde schermafbeelding en algemene toestelgegevens door aan de ontwikkelaar. Die worden alleen gebruikt om het spel te verbeteren en met niemand anders gedeeld.

De promosite white-sum.steefbeest.nl plaatst geen cookies en gebruikt geen trackers.

Vragen: privacy@steefbeest.nl

Laatst bijgewerkt: 19 november 2026
```

App Privacy in App Store Connect: **Data Not Collected**. Tracking: **No**. Basis: design 16.7 (no network code in the
game or White Kit, only a local progress file). Re-check before every release that adds a feature with network access
(phase 5: server, results, accounts); from then on the answers change.

## 8. Age rating

Answers for Apple's age rating questionnaire. Every content question is answered None or No:

| Topic | Answer |
|---|---|
| Violence (cartoon, fantasy, realistic), horror or fear themes | None |
| Sexual content, nudity, profanity or crude humour | None |
| Alcohol, tobacco, drug use or references | None |
| Mature or suggestive themes; medical or treatment information | None |
| Simulated gambling, real gambling, contests, loot boxes | None / No |
| Unrestricted web access | No |
| User-generated content, messaging or chat | No |
| Advertising | No |
| Parental controls, age assurance | No (not needed) |

Expected result: **4+**. The game is aimed at players aged 10 and up because of its difficulty, not its content; that
is not an age rating matter. Do not choose the Kids category: it brings extra review rules for no gain.

## 9. TestFlight test information

| Field | Value |
|---|---|
| Feedback email | Open (owner decides; existing address: privacy@steefbeest.nl) |
| Marketing URL | https://white-sum.steefbeest.nl/en/ |
| Privacy policy URL | https://white-sum.steefbeest.nl/en/privacy/ |
| Sign-in required | No |
| Contact for Beta App Review | The owner's name, phone and email (entered in App Store Connect only, never in the repository) |

Beta App Description, English:

```
White Sum is a calm number puzzle. Tiles numbered 1 to 5 fall under gravity; swap or slide them so that touching tiles in a row or column add up to exactly 10 and vanish. Clear the board in as few moves as possible. This test version has 40 practice sets of three puzzles (easy, medium, hard).
```

Beta App Description, Dutch:

```
White Sum is een rustige rekenpuzzel. Stenen met een getal van 1 tot 5 vallen omlaag; wissel of schuif ze zo dat aaneengesloten stenen in een rij of kolom samen precies 10 zijn en verdwijnen. Maak het bord leeg in zo min mogelijk zetten. Deze testversie heeft 40 oefensets van drie puzzels (makkelijk, middel, moeilijk).
```

What to Test, English:

```
Play a few sets on each level. We would like to hear:
- Is the ten rule clear after the hint line?
- Are the numerals and the row and column totals easy to read?
- Do swipes and taps do what you expect? Is anything hidden behind the notch or the home bar?
- Is adding up fun, or does it feel like homework?
Use the TestFlight screenshot feedback (take a screenshot in the game) for anything that looks wrong.
```

What to Test, Dutch:

```
Speel een paar sets op elk niveau. We horen graag:
- Is de tienregel duidelijk na de hintregel?
- Zijn de getallen en de totalen van rij en kolom goed leesbaar?
- Doen vegen en tikken wat je verwacht? Valt er iets achter de notch of de thuisbalk?
- Is optellen leuk, of voelt het als huiswerk?
Gebruik de schermafbeelding-feedback van TestFlight (maak een schermafbeelding in het spel) voor alles wat er vreemd uitziet.
```

## 10. Later: App Review notes

```
White Sum is an offline puzzle game. No account or login is needed and the app makes no network connections. Open the app and play: swap two neighbouring tiles by swiping, or slide a tile sideways into an empty spot; a row or column of touching tiles that adds up to exactly 10 vanishes.
```
