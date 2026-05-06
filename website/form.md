---
title: Aanmelden
form:
    name: aanmeldformulier
    action: /praktisch
    fields:
        - name: naam
          label: Hoe heet je?
          placeholder: Je volledige naam
          type: text
          validate:
            required: true

        - name: email
          label: E-mailadres
          placeholder: Je mailadres zodat we kunnen bevestigen
          type: email
          validate:
            required: true

        - name: onderwerp
          label: Wat wil je doen?
          type: select
          options:
            installatie: Ik wil Linux installeren
            hulp: Ik heb een specifieke vraag/probleem
            vrijwilliger: Ik wil graag helpen als vrijwilliger
            kijken: Ik kom gewoon even sfeer proeven

        - name: bericht
          label: Heb je al een specifieke laptop of vraag?
          placeholder: Bijv. "Ik heb een Acer Spin 1 uit 2018..."
          type: textarea

    buttons:
        - type: submit
          value: Verzenden
        - type: reset
          value: Wissen

    process:
        - email:
            from: "{{ config.plugins.email.from }}"
            to: "{{ config.plugins.email.to }}"
            subject: "[Aanmelding Website] {{ form.value.naam|e }}"
            body: "{% include 'forms/data.html.twig' %}"
        - message: Bedankt voor je bericht! We nemen snel contact met je op.
        - display: /bedankt
---

# Meld je aan
Wil je zeker zijn van een plekje bij een van onze groepjes op vrijdag? Vul dan even dit formulier in.
