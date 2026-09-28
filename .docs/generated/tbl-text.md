| Column | Status | Description |
|---|---|---|
| `slot` | R | Where it appears: about, messages, energy_intro, map_note, etc. |
| `ref_area` | R | ISO3, or ALL for shared boilerplate. |
| `time_period` | R | Year, or ALL. |
| `order` | R | Position within a slot that holds several items. |
| `title` | O | Heading text. |
| `body` | C | The text, one paragraph, no line breaks; exactly one of body/file is filled. |
| `file` | C | Path under content/text/ for anything longer; exactly one of body/file is filled. |
| `status` | R | DRAFT or PUBLISHED; production shows only PUBLISHED. |
| `updated_on` | R | ISO date. |

: Columns of `TEXT.csv` {#tbl-text}
