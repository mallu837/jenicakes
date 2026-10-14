module.exports = {
  async rewrites() {
    return [
      {
        source: '/loader.lua',
        destination: '/api/loader',
      },
    ];
  },
};
