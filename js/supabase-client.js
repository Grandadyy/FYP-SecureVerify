(function(){
  const c=window.SECUREVERIFY_CONFIG||{};
  const valid=c.SUPABASE_URL&&c.SUPABASE_ANON_KEY&&!c.SUPABASE_URL.includes('PASTE_')&&!c.SUPABASE_ANON_KEY.includes('PASTE_');
  window.svConfigured=!!valid;
  window.svClient=valid?window.supabase.createClient(c.SUPABASE_URL,c.SUPABASE_ANON_KEY):null;
  window.svRequireConfig=function(){if(!window.svConfigured){alert('SecureVerify is not connected yet. Follow SETUP-GUIDE.md and add your Supabase URL and anon/publishable key to js/config.js.');return false}return true};
})();
