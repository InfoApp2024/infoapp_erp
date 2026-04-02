<?php
// backend/chatbot/config.php
// Obtén tu API Key gratuita aquí: https://aistudio.google.com/app/apikey

// Definir la clave asegurando que no haya espacios en blanco
define('GEMINI_API_KEY', trim('AIzaSyCZ5kfcaTSutJHRiD6VBJTAkDkKNMVlG1s'));

// Usamos 'gemini-flash-latest' que es un alias seguro y gratuito
define('GEMINI_API_URL', 'https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent?key=' . GEMINI_API_KEY);
