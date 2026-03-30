
# Maclean — Guia de Uso

## 0. Pré-requisitos (tornando o script global)

1. Baixe o script `maclean.sh` para a pasta **Downloads**
2. Abra o Terminal
3. Navegue até a pasta:

```bash
cd ~/Downloads
```

4. Mova o script para o diretório global:

```bash
sudo mv maclean.sh /usr/local/bin/maclean
```

5. Conceda permissão de execução:

```bash
sudo chmod +x /usr/local/bin/maclean
```

6. Teste a instalação:

```bash
maclean --dry-run
```

---

## Permitir acesso total ao disco (necessário)

1. Abra **Configurações do Sistema**
2. Vá em **Privacidade e Segurança**
3. Clique em **Acesso Total ao Disco**
4. Adicione:
    - Terminal (ou iTerm, se você usa)
5. Reinicie o Terminal

---

## 1. Permissão de execução (caso rode localmente)

```bash
chmod +x maclean.sh
```

> Não é necessário executar:
> ```bash
> chmod +x maclean
> ```

---

## 2. Primeira execução (recomendado)

Sempre comece com o modo de simulação:

```bash
./maclean.sh --dry-run
```

Ou, se instalado globalmente:

```bash
maclean --dry-run
```

---

## 3. Limpeza leve (sem sudo)

```bash
./maclean.sh --safe
```

Ou:

```bash
maclean --safe
```

---

## 4. Limpeza completa

```bash
sudo ./maclean.sh
```

Ou:

```bash
sudo maclean
```

---

## 5. Limpeza agressiva

Inclui limpeza de:

- Homebrew
- npm
- pip
- Docker
- Xcode

```bash
sudo ./maclean.sh --aggressive
```

Ou:

```bash
sudo maclean --aggressive
```

---

## 6. Automação com `launchd` (recomendado)

### 1. Criar o arquivo de agendamento

```bash
nano ~/Library/LaunchAgents/com.maclean.cleanup.plist
```

---

### 2. Cole a configuração abaixo

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
 "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>

    <key>Label</key>
    <string>com.maclean.cleanup</string>

    <key>ProgramArguments</key>
    <array>
      <string>/usr/local/bin/maclean</string>
      <string>--auto</string>
      <string>--safe</string>
    </array>

    <key>StartCalendarInterval</key>
    <dict>
      <key>Day</key>
      <integer>1</integer>
      <key>Hour</key>
      <integer>3</integer>
      <key>Minute</key>
      <integer>0</integer>
    </dict>

    <key>StandardOutPath</key>
    <string>/tmp/maclean.log</string>

    <key>StandardErrorPath</key>
    <string>/tmp/maclean.error.log</string>

  </dict>
</plist>
```

---

### 3. Salvar o arquivo

- `Ctrl + O` → Enter
- `Ctrl + X`

---

### 4. Ativar o agendamento

```bash
launchctl load ~/Library/LaunchAgents/com.maclean.cleanup.plist
```

---

### 5. Testar manualmente

```bash
launchctl start com.maclean.cleanup
```

---

### 6. Ver logs

Saída:

```bash
cat /tmp/maclean.log
```

Erros:

```bash
cat /tmp/maclean.error.log
```

---

## O que a automação faz

Executa automaticamente:

```bash
maclean --auto --safe
```

- Todo dia **1º do mês**
- Às **03:00 da manhã**

---

## Observações

- O Mac precisa estar ligado
- Se estiver em repouso (sleep), a tarefa pode não executar
- Executa sem `sudo` (modo seguro)

---

## Personalização (opcional)

### Rodar semanalmente (segunda-feira às 03:00)

Substitua:

```xml
<key>Day</key>
<integer>1</integer>
```

Por:

```xml
<key>Weekday</key>
<integer>1</integer>
```

---

### Rodar modo agressivo (mensal)

Substitua:

```xml
<string>--safe</string>
```

Por:

```xml
<string>--aggressive</string>
```

---

### Rodar ao iniciar o Mac

Adicione dentro do `<dict>`:

```xml
<key>RunAtLoad</key>
<true/>
```

---

## Remover automação

```bash
launchctl unload ~/Library/LaunchAgents/com.maclean.cleanup.plist
```

