# Getting the project onto your machine

This project was built in a remote sandbox. The packaged zip lives at:

```text
/home/workdir/artifacts/clinical-safety-net.zip
```

## Download the zip

Use the download control in this chat/UI for:

- `clinical-safety-net.zip`  
  or the folder `clinical-safety-net/`

Save it to your **Desktop** (or any folder you prefer).

## Windows (CMD)

```cmd
cd %USERPROFILE%\Desktop
:: after downloading clinical-safety-net.zip to Desktop:
tar -xf clinical-safety-net.zip
:: or use PowerShell Expand-Archive:
powershell -command "Expand-Archive -Path clinical-safety-net.zip -DestinationPath ."
cd clinical-safety-net
dir
```

## macOS / Linux (Terminal)

```bash
cd ~/Desktop
# after downloading clinical-safety-net.zip to Desktop:
unzip clinical-safety-net.zip
cd clinical-safety-net
ls -la
```

## What you should see

```text
README.md
GETTING_STARTED_LOCAL.md
database/
data/
docs/
examples/
n8n/
rules/
tests/
scripts/
```

## Next steps

1. Open `README.md` for the portfolio overview.  
2. Follow `docs/setup.md` to run the database + n8n workflow.  
3. Push the folder to your GitHub repo when ready:

```bash
cd clinical-safety-net
git init
git add .
git commit -m "Initial commit: Autonomous Clinical Drug-Interaction & Dosage Safety Net"
git branch -M main
git remote add origin https://github.com/<your-username>/<your-repo>.git
git push -u origin main
```

Then link the repo from your portfolio site.
