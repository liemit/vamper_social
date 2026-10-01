<?php
echo "<h2>🛠 Apache Module Check</h2>";
if (function_exists('apache_get_modules')) {
    $modules = apache_get_modules();
    if (in_array('mod_headers', $modules)) {
        echo "<p style='color:green'>✅ <b>mod_headers</b> is ENABLED!</p>";
    } else {
        echo "<p style='color:red'>❌ <b>mod_headers</b> is DISABLED!</p>";
    }

    if (in_array('mod_rewrite', $modules)) {
        echo "<p style='color:green'>✅ <b>mod_rewrite</b> is ENABLED!</p>";
    } else {
        echo "<p style='color:red'>❌ <b>mod_rewrite</b> is DISABLED!</p>";
    }
} else {
    echo "<p style='color:orange'>⚠️ Cannot check modules via PHP on this server (non-Apache or disabled function).</p>";
}
?>
