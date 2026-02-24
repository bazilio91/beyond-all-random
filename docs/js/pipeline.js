const Pipeline = {
  encode(str) {
    return btoa(unescape(encodeURIComponent(str)))
      .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  },
  build(headers, body) {
    return this.encode(headers + '\n' + body);
  }
};
