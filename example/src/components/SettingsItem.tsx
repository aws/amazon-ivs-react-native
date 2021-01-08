import React from 'react';
import { View, StyleSheet, StyleProp, ViewStyle } from 'react-native';
import { Caption } from 'react-native-paper';

type Props = {
  label: string;
  children?: any;
  style?: StyleProp<ViewStyle>;
};

const SettingsItem = ({ label, children, style }: Props) => (
  <View style={[styles.container, style]}>
    <Caption style={styles.label}>{label.toUpperCase()}</Caption>
    {children}
  </View>
);

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 5,
  },
  label: {
    paddingRight: 10,
    width: 100,
  },
});

export default SettingsItem;
