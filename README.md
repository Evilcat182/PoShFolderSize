**Description**

- Gets total size of Folders using Robocopy.
- No files will be written, only read access.
- Much faster than Powerchell or .NET functions.
- No 260 char Path Limitation.
- Only works with GERMAN or ENGLISH OS sp far



**Usage**

Get Size of folder C:\Windows\temp
```
PS C:\Users\lhgsct3_adm> Get-FolderSize -Path C:\Windows\temp

Size(GB) Size             Path
-------- ----             ----
0,01     14981473         C:\Windows\temp
```


Get Size of current Location

```
PS C:\Users\lhgsct3_adm> Get-FolderSize

Size(GB) Size             Path
-------- ----             ----
3,43     3688032494       C:\Users\lhgsct3_adm
```
