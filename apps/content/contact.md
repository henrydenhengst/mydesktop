<form id="contactForm" action="{{< param contactEndpoint >}}" method="POST">
    <input type="text" name="website" style="display:none !important" tabindex="-1" autocomplete="off">
    
    <div>
        <label>Naam:</label><br>
        <input type="text" name="name" required style="width:100%">
    </div>
    <div>
        <label>E-mail:</label><br>
        <input type="email" name="email" required style="width:100%">
    </div>
    <div>
        <label>Bericht:</label><br>
        <textarea name="message" required style="width:100%; height:150px;"></textarea>
    </div>
    <button type="submit" id="submitBtn">Verstuur bericht</button>
</form>

<div id="formResponse" style="display:none; margin-top:20px; padding:10px; border:1px solid #ccc;"></div>

<script>
document.getElementById('contactForm').addEventListener('submit', function(e) {
    e.preventDefault();
    const btn = document.getElementById('submitBtn');
    const responseDiv = document.getElementById('formResponse');
    
    btn.disabled = true;
    btn.innerText = "Verzenden...";

    fetch(this.action, {
        method: 'POST',
        body: new FormData(this)
    })
    .then(res => res.text())
    .then(data => {
        responseDiv.innerHTML = data;
        responseDiv.style.display = 'block';
        if(data.includes("Bedankt")) this.reset();
    })
    .catch(() => {
        responseDiv.innerHTML = "Er ging iets mis met de verbinding.";
        responseDiv.style.display = 'block';
    })
    .finally(() => {
        btn.disabled = false;
        btn.innerText = "Verstuur bericht";
    });
});
</script>
