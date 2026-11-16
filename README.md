# Soul Shard Cap

A small Warlock addon for **World of Warcraft: Forever**. Your Soul Bag's size is your Soul Shard limit. Farm with Drain Soul, and the extra shards never pile up in your main bags.

With a 16-slot Box of Souls you keep 16 shards. When Drain Soul creates a 17th, it's deleted the next time you press a key. Any soul bag size works (10, 12, 16, 20…). With two soul bags, the limit is both sizes added together.

> **Status: beta.** Tested on WoW: Forever (interface 16001) with a 16-slot Box of Souls. Bug reports are welcome. Please open an issue.

## Why "the next key press" and not instantly?

Blizzard only lets addons delete items during a real key press or mouse click, and only one item per press. No addon can stop a shard from landing in your bag. While you're farming you press keys constantly, so the extra shard is usually gone within a second of the kill.

## Safety

- Only deletes out of combat. Shards that pile up during a fight are removed one per key press afterward.
- Never deletes while you're holding an item on your cursor.
- Deletes shards in your normal bags first, and never more than the extra.
- No soul bag equipped means nothing is deleted, unless you set a limit with `/ssc max`.

## Install

1. Download the latest zip from [Releases](../../releases) (or CurseForge, once it's listed).
2. Unzip it into your Forever `Interface\AddOns` folder, so you end up with `Interface\AddOns\SoulShardCap\SoulShardCap.toc`.
   To find the folder: Battle.net app → World of Warcraft → pick the Forever version → gear icon → **Show in Explorer** → Forever folder → `Interface` → `AddOns`.
3. Start the game. At character select, click **AddOns** and make sure **Soul Shard Cap** is checked.

## Commands

| Command | What it does |
|---|---|
| `/ssc` | Show your shard count and limit |
| `/ssc on` / `/ssc off` | Turn auto-delete on or off |
| `/ssc max 20` | Use a fixed limit instead of your soul bag size |
| `/ssc max auto` | Go back to your soul bag size (default) |
| `/ssc button` | Show or hide the "Delete extra Soul Shard" button |
| `/ssc quiet` | Turn chat messages on or off |
| `/ssc debug` | Print a diagnostic report and turn on logging |
| `/ssc debug off` / `/ssc debug clear` | Turn logging off, or empty the log |

The **Delete extra Soul Shard** button shows up only while you're over the limit. It's a backup if key presses ever don't work for you. Shift+drag moves it. A macro with `/click SoulShardCapButton` does the same thing.

## Reporting a bug

1. Type `/ssc debug`, reproduce the problem, then `/reload`.
2. Open `World of Warcraft\_forever_\WTF\Account\<YOUR ACCOUNT>\SavedVariables\SoulShardCap.lua` in Notepad and copy the lines under `log`.
3. Open an issue with the log, your soul bag's name and size, and what you expected to happen.

## Releasing a new version (maintainer notes)

1. Add the changes to the top of `CHANGELOG.md` and push.
2. On GitHub, go to **Releases** and choose **Draft a new release**. Create a new tag such as `v1.3.0-beta`, then click **Publish release**.
3. The "Package and release" workflow under the **Actions** tab builds the zip, attaches it to the GitHub release, and uploads it to CurseForge.
   - A tag with `beta` in it uploads as a Beta file, one with `alpha` as an Alpha file, and a plain `v1.3.0` as a full Release.
   - The version number in the addon comes from the tag automatically.

## License

MIT. See [LICENSE](LICENSE).
