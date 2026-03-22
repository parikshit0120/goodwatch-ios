import { Image } from 'react-native';

export default function Logo({ size = 120 }) {
  return (
    <Image
      source={require('../GoodWatch/Assets.xcassets/AppIcon.appiconset/icon-1024.png')}
      style={{ width: size, height: size, resizeMode: 'contain' }}
    />
  );
}
