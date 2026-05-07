---
title: Aanmelden & Contact
form:
    name: aanmeldformulier
    template: formdata
    action: /aanmelden
    
    fields:
        - name: naam
          label: Hoe heet je?
          placeholder: Je volledige naam
          type: text
          validate:
            required: true

        - name: email
          label: E-mailadres
          placeholder: Je e-mailadres voor de bevestiging
          type: email
          validate:
            required: true

        - name: interesse
          label: Waarvoor kom je langs?
          type: select
          options:
            installeren: Ik wil Linux laten installeren op mijn hardware
            hulp: Ik heb een specifieke vraag of probleem
            vrijwilliger: Ik wil graag helpen als vrijwilliger
            kijken: Ik kom gewoon even sfeer proeven
            anders: Ik heb een andere vraag

        - name: hardware
          label: Welke computer breng je mee? (Indien van toepassing)
          placeholder: Bijv. "Laptop, HP ProBook uit 2014"
          type: text

        - name: bericht
          label: Je bericht of vraag
          placeholder: Vertel ons kort wat we voor je kunnen doen...
          type: textarea
          validate:
            required: true

    buttons:
        - type: submit
          value: Aanmelding versturen
        - type: reset
          value: Wissen

    process:
        - email:
            from: "{{ config.plugins.email.from }}"
            to: "vcp5693@duck.com"
            reply_to: "{{ form.value.email }}"
            subject: "[Linux Café Haarlem] Aanmelding van {{ form.value.naam|e }}"
            body: "{% include 'forms/data.html.twig' %}"
        - message: "Bedankt voor je bericht! We hebben het verstuurd naar ons team. Tot snel in het café!"
        - display: /bedankt
---

# Meld je aan voor de vrijdag

Omdat we in kleine groepjes van **maximaal 4 personen** werken, is het handig als je je vooraf aanmeldt. Zo weten we zeker dat we genoeg koffie en experts klaar hebben staan!

Vul het onderstaande formulier in, dan nemen we zo snel mogelijk contact met je op. Liever direct contact? Gebruik dan onze Telegram-groep.

---
