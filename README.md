# Patches branch
When you run git diff A B, Git shows you how to go from commit/ref A (old) to commit/ref B (new). So:

git diff master patches generates a patch describing “changes that transform master into patches.”
If you apply that patch on top of master, it should yield the state of patches.
git diff patches master does the opposite: it shows changes that transform patches into master.
Therefore, the order matters depending on which base you want to apply the patch to:

If you want a patch you can apply to master so it becomes identical to patches, then use:

``` bash
git diff master patches -- platformio.ini > build_environment.patch
This says “Take master as the old version, patches as the new version. Show me what changed to go from master to patches.”
```

If instead you need a patch that, when applied to patches, brings it to master, then reverse it:

```bash
git diff patches master -- platformio.ini > build_environment.patch
```

In short, the first argument to git diff is considered the “old” commit and the second is the “new” commit. When you apply that patch, you typically do so in a working tree that matches the “old” commit, so it will end up in the “new” commit state.


# WORKFLOW

Stay on a patches branch whose sole purpose is to hold patch files (rather than committed source changes).
Temporarily pull in a file from master, modify it, and generate a patch describing those changes.
Discard or remove the modified file so that your patches branch only keeps the .patch file.
Below is a quick breakdown of the steps and some clarifications:

1. git checkout patches
You switch to your patches branch—this branch is dedicated to storing patch files.

2. Update tags `git fetch upstream --tag`

3. Checkout files to patch `git checkout <tag> -- /path/to/file`
You pull in the file from the master branch into your working directory. 
**This means:**
You’re not switching branches again; you remain on patches.
You’re just copying the version of /path/to/file from <tag> into your current working tree.
At this point, your working directory has the file as it exists in master, but your active branch is still patches. To list tags `git tag -l`

3. Make modifications
You edit /path/to/file as needed.

4. Create the patch
bash
Copia codice
git diff -- /path/to/file > my_new_patch.patch
This command compares old vs. patches (new) but only for the specific file.
The result is a patch that describes how to go from the version in master to the newly modified version you have in your working directory (which is on patches).
You store it in a file called my_new_patch.patch.

5. Delete the modified file
Since you don’t want the modified file itself in the patches branch (only the patch), you remove it:

```bash
rm /path/to/file
```
(This effectively cleans up your working directory so you’re back to a “no local changes” state on patches, aside from the newly created patch file.)

Alternatively, you could do something like:

6. Commit the patch file
```bash
git add my_new_patch.patch
git commit -m "Add patch for /path/to/file"
```
This way, the only thing that gets added to your patches branch is the .patch file.


# PATCH
```bash
git chekout <tag>
git checkout patches -- applyPatches.sh
```