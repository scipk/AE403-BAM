load('ML_training_data.mat')

X = ML_data.inputs';
Y = ML_data.outputs';

net = feedforwardnet([16 16]);
net = train(net, X, Y);

save('learning_model.mat','net');