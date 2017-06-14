describe port(6432) do
    it { should be_listening }
    its('protocols') {should include 'tcp'}
end

