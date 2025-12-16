import VusButton from './components/vus-button';

import VusIcon from './components/vus-icon';

import VusPanel from './components/vus-panle';

import VusUtils from './utils';

const components = {
    VusButton,VusIcon,VusPanel
};

const vus = {
    ...components
};

const install = function(Vue, opts = {}) {

    if (install.installed) return;

    Object.keys(vus).forEach(key => {
        Vue.component(key, vus[key]);
    });

    VusUtils.SvgUtils.loading(require.context('./styles/common/icons/svg', false, /\.svg$/));

    let svg = opts['icons'];
    if(svg){
        VusUtils.SvgUtils.loading(svg);
    }
};

// auto install
if (typeof window !== 'undefined' && window.Vue) {
    install(window.Vue);
}

const API = {
    version: process.env.VERSION, // eslint-disable-line no-undef
    install,
    ...components
};

module.exports.default = module.exports = API;   // eslint-disable-line no-undef
